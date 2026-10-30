//! File-change notification for directories. A `Watcher` is one pollable fd
//! that turns readable while events are queued; hand `fd` to the Wayland
//! loop or a `poll` and call `drain` when it fires. Linux backs it with
//! inotify; events carry the entry name and neutral flags, so a backend
//! without names can synthesize them by diffing the directory.
const std = @import("std");
const linux = std.os.linux;

/// One watched directory. Negative means none.
pub const Watch = i32;
pub const none: Watch = -1;

/// What to be told about (`add`), and what happened (`Event.flags`).
pub const Flags = packed struct(u16) {
    /// An entry appeared in the directory.
    created: bool = false,
    deleted: bool = false,
    /// An entry's contents changed. Often half-written; prefer `written`.
    modified: bool = false,
    moved_from: bool = false,
    moved_to: bool = false,
    /// A writer closed an entry: the contents are complete.
    written: bool = false,
    attrib: bool = false,
    /// Event only: the watched directory itself was deleted, moved or
    /// unmounted. Always reported, and followed by `dropped`.
    self_gone: bool = false,
    /// Event only: the watch no longer exists (removed, or its directory
    /// went away). Always reported.
    dropped: bool = false,
    /// Event only: the queue overflowed and events were lost.
    overflow: bool = false,
    /// Event only: the entry is a directory.
    is_dir: bool = false,
    _: u5 = 0,

    /// What a directory listing shows: names, contents, attributes.
    pub const listing: Flags = .{ .created = true, .deleted = true, .moved_from = true, .moved_to = true, .written = true, .attrib = true };

    pub fn matches(self: Flags, other: Flags) bool {
        return @as(u16, @bitCast(self)) & @as(u16, @bitCast(other)) != 0;
    }

    /// Something happened to the directory's contents or the directory
    /// itself, or events were lost. Not the bookkeeping `dropped` alone.
    pub fn isChange(self: Flags) bool {
        const bookkeeping: Flags = .{ .dropped = true, .is_dir = true };
        return @as(u16, @bitCast(self)) & ~@as(u16, @bitCast(bookkeeping)) != 0;
    }

    /// The watch is dead: re-add it if the directory is still wanted.
    pub fn lost(self: Flags) bool {
        return self.matches(.{ .self_gone = true, .dropped = true });
    }
};

pub const Event = struct {
    watch: Watch,
    /// The entry inside the watched directory; empty for the directory itself.
    /// Valid only during the callback.
    name: []const u8,
    flags: Flags,
};

pub const Watcher = struct {
    fd: i32 = -1,

    pub fn init() error{Unavailable}!Watcher {
        const rc = linux.inotify_init1(linux.IN.NONBLOCK | linux.IN.CLOEXEC);
        if (linux.errno(rc) != .SUCCESS) return error.Unavailable;
        return .{ .fd = @intCast(rc) };
    }

    pub fn deinit(self: *Watcher) void {
        if (self.fd >= 0) _ = linux.close(self.fd);
        self.fd = -1;
    }

    /// Watches a directory, which must exist. Adding one already watched
    /// returns its existing `Watch`, changes only the interest, and queues no
    /// events, so a set of watches can be refreshed before the old ones go.
    pub fn add(self: Watcher, path: []const u8, interest: Flags) ?Watch {
        var buf: [std.posix.PATH_MAX]u8 = undefined;
        const z = std.fmt.bufPrintSentinel(&buf, "{s}", .{path}, 0) catch return null;
        const rc = linux.inotify_add_watch(self.fd, z.ptr, mask(interest));
        if (linux.errno(rc) != .SUCCESS) return null;
        return @intCast(rc);
    }

    /// `add`, falling back to the nearest existing parent directory, for
    /// places that may not exist yet. Call again after events to move the
    /// watch down once the directory has been created.
    pub fn addOrParent(self: Watcher, path: []const u8, interest: Flags) ?Watch {
        var at = path;
        while (true) {
            if (self.add(at, interest)) |watch| return watch;
            at = std.fs.path.dirname(at) orelse return null;
        }
    }

    pub fn remove(self: Watcher, watch: Watch) void {
        _ = linux.inotify_rm_watch(self.fd, watch);
    }

    /// Calls `onEvent(ctx, event)` for every queued event. `Broken` means the
    /// stream ended or was malformed: stop using this watcher.
    pub fn drain(self: Watcher, ctx: anytype, comptime onEvent: fn (@TypeOf(ctx), Event) void) error{Broken}!void {
        return self.drainBounded(ctx, onEvent, std.math.maxInt(usize));
    }

    /// `drain`, reading at most `max_batches` buffers (8 KiB, a few hundred
    /// events each); the fd stays readable if more remain.
    pub fn drainBounded(self: Watcher, ctx: anytype, comptime onEvent: fn (@TypeOf(ctx), Event) void, max_batches: usize) error{Broken}!void {
        var buf: [8192]u8 align(@alignOf(linux.inotify_event)) = undefined;
        var batches: usize = 0;
        while (batches < max_batches) : (batches += 1) {
            const rc = linux.read(self.fd, &buf, buf.len);
            switch (linux.errno(rc)) {
                .SUCCESS => {},
                .INTR => continue,
                .AGAIN => return,
                else => return error.Broken,
            }
            if (rc == 0) return error.Broken;
            var off: usize = 0;
            while (off < rc) {
                const body = off + @sizeOf(linux.inotify_event);
                if (body > rc) return error.Broken;
                const raw: *const linux.inotify_event = @ptrCast(@alignCast(&buf[off]));
                if (raw.len > rc - body) return error.Broken;
                onEvent(ctx, .{
                    .watch = raw.wd,
                    .name = std.mem.sliceTo(buf[body..][0..raw.len], 0),
                    .flags = flags(raw.mask),
                });
                off = body + raw.len;
            }
        }
    }

    /// Discards the queued events. True when there were any.
    pub fn flush(self: Watcher) bool {
        var seen = false;
        self.drain(&seen, struct {
            fn event(s: *bool, _: Event) void {
                s.* = true;
            }
        }.event) catch return true;
        return seen;
    }
};

fn mask(interest: Flags) u32 {
    var m: u32 = linux.IN.DELETE_SELF | linux.IN.MOVE_SELF;
    if (interest.created) m |= linux.IN.CREATE;
    if (interest.deleted) m |= linux.IN.DELETE;
    if (interest.modified) m |= linux.IN.MODIFY;
    if (interest.moved_from) m |= linux.IN.MOVED_FROM;
    if (interest.moved_to) m |= linux.IN.MOVED_TO;
    if (interest.written) m |= linux.IN.CLOSE_WRITE;
    if (interest.attrib) m |= linux.IN.ATTRIB;
    return m;
}

fn flags(m: u32) Flags {
    return .{
        .created = m & linux.IN.CREATE != 0,
        .deleted = m & linux.IN.DELETE != 0,
        .modified = m & linux.IN.MODIFY != 0,
        .moved_from = m & linux.IN.MOVED_FROM != 0,
        .moved_to = m & linux.IN.MOVED_TO != 0,
        .written = m & linux.IN.CLOSE_WRITE != 0,
        .attrib = m & linux.IN.ATTRIB != 0,
        .self_gone = m & (linux.IN.DELETE_SELF | linux.IN.MOVE_SELF | linux.IN.UNMOUNT) != 0,
        .dropped = m & linux.IN.IGNORED != 0,
        .overflow = m & linux.IN.Q_OVERFLOW != 0,
        .is_dir = m & linux.IN.ISDIR != 0,
    };
}

const Seen = struct {
    watch: Watch = none,
    names: [8][16]u8 = undefined,
    flags: [8]Flags = undefined,
    count: usize = 0,

    fn event(self: *Seen, ev: Event) void {
        if (self.count == self.names.len) return;
        self.watch = ev.watch;
        self.names[self.count] = @splat(0);
        @memcpy(self.names[self.count][0..ev.name.len], ev.name);
        self.flags[self.count] = ev.flags;
        self.count += 1;
    }

    fn name(self: *const Seen, i: usize) []const u8 {
        return std.mem.sliceTo(&self.names[i], 0);
    }
};

fn tempDirectory(tmp: anytype) ![:0]u8 {
    return tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
}

test "a watcher reports names and completed writes in a directory" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tempDirectory(&tmp);
    defer t.allocator.free(root);
    var watcher = try Watcher.init();
    defer watcher.deinit();
    const watch = watcher.add(root, .{ .written = true, .moved_to = true }).?;
    try t.expect(!watcher.flush());

    try tmp.dir.writeFile(t.io, .{ .sub_path = "config.toml", .data = "a" });
    var seen: Seen = .{};
    try watcher.drain(&seen, Seen.event);
    try t.expectEqual(@as(usize, 1), seen.count);
    try t.expectEqual(watch, seen.watch);
    try t.expectEqualStrings("config.toml", seen.name(0));
    try t.expect(seen.flags[0].written and seen.flags[0].isChange() and !seen.flags[0].lost());

    // An atomic replacement arrives as a move into the directory.
    try tmp.dir.writeFile(t.io, .{ .sub_path = "config.tmp", .data = "b" });
    _ = watcher.flush();
    try tmp.dir.rename("config.tmp", tmp.dir, "config.toml", t.io);
    seen = .{};
    try watcher.drain(&seen, Seen.event);
    try t.expectEqual(@as(usize, 1), seen.count);
    try t.expect(seen.flags[0].moved_to and !seen.flags[0].written);
}

test "a directory that goes away reports a lost watch" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tempDirectory(&tmp);
    defer t.allocator.free(root);
    const inner = try std.fs.path.join(t.allocator, &.{ root, "inner" });
    defer t.allocator.free(inner);
    try tmp.dir.createDir(t.io, "inner", .default_dir);
    var watcher = try Watcher.init();
    defer watcher.deinit();
    const watch = watcher.add(inner, Flags.listing).?;
    try tmp.dir.deleteDir(t.io, "inner");
    var seen: Seen = .{};
    try watcher.drain(&seen, Seen.event);
    try t.expect(seen.count >= 1);
    var lost = false;
    for (seen.flags[0..seen.count]) |flag| lost = lost or flag.lost();
    try t.expect(lost);
    try t.expectEqual(watch, seen.watch);
    // A removal made by the owner only drops the watch: not a change.
    try tmp.dir.createDir(t.io, "inner", .default_dir);
    const readded = watcher.add(inner, Flags.listing).?;
    _ = watcher.flush();
    watcher.remove(readded);
    seen = .{};
    try watcher.drain(&seen, Seen.event);
    try t.expectEqual(@as(usize, 1), seen.count);
    try t.expect(seen.flags[0].dropped and !seen.flags[0].isChange());
}

test "a missing directory falls back to its nearest parent and re-adding keeps the watch" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tempDirectory(&tmp);
    defer t.allocator.free(root);
    const missing = try std.fs.path.join(t.allocator, &.{ root, "not", "yet" });
    defer t.allocator.free(missing);
    var watcher = try Watcher.init();
    defer watcher.deinit();
    try t.expect(watcher.add(missing, Flags.listing) == null);
    const parent = watcher.addOrParent(missing, Flags.listing).?;
    try t.expectEqual(parent, watcher.add(root, Flags.listing).?);
    try tmp.dir.createDir(t.io, "not", .default_dir);
    var seen: Seen = .{};
    try watcher.drain(&seen, Seen.event);
    try t.expectEqual(@as(usize, 1), seen.count);
    try t.expect(seen.flags[0].created and seen.flags[0].is_dir);
    try t.expectEqualStrings("not", seen.name(0));
}
