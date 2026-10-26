//! Linux power-supply snapshots, never read during paint.
//!
//! A read is not free: the battery's `uevent` evaluates ACPI `_BST` and the AC
//! adapter's `_PSR`, measured at 1-1.5 ms of kernel CPU charged to the
//! compositor.
//! Kernel power_supply uevents (plug, unplug, charge state) trigger an
//! immediate read; capacity and time estimates are re-read on the taskbar's
//! minute tick, because many firmwares never announce percentage changes.
const i18n = @import("i18n");
const std = @import("std");
const linux = std.os.linux;

pub const State = struct {
    percent: ?u8 = null,
    plugged: bool = false,
    charging: bool = false,
    discharging: bool = false,
    full: bool = false,
    health: ?u8 = null,
    full_wh: ?f64 = null,
    cycles: ?u32 = null,
    remaining_minutes: ?u32 = null,

    pub fn estimate(self: State, buf: []u8) ?[]const u8 {
        const minutes = self.remaining_minutes orelse return null;
        var duration_buf: [96]u8 = undefined;
        const duration = if (minutes < 60)
            i18n.fmt(&duration_buf, i18n.tr("{minutes}min"), .{ .minutes = minutes }) catch return null
        else
            i18n.fmt(&duration_buf, i18n.tr("{hours}h {minutes}min"), .{ .hours = minutes / 60, .minutes = minutes % 60 }) catch return null;
        return i18n.fmt(buf, i18n.tr("~{time} left"), .{ .time = duration }) catch null;
    }

    pub fn status(self: State) []const u8 {
        if (self.charging) return i18n.tr("Charging");
        if (self.full) return i18n.tr("Fully Charged");
        if (self.plugged) return i18n.tr("Plugged In");
        return i18n.tr("On Battery");
    }
};

/// One warning per low-battery episode, shared by every output. Missing
/// snapshots do not rearm it; only a real recovery or end of discharge does.
pub const Warning = struct {
    notified: bool = false,

    pub const Action = enum { none, show, clear };

    pub fn update(self: *Warning, state: State) Action {
        const percent = state.percent orelse return .none;
        if (percent > 10 or !state.discharging or state.charging or state.full) {
            self.notified = false;
            return .clear;
        }
        if (self.notified) return .none;
        self.notified = true;
        return .show;
    }
};

fn field(contents: []const u8, key: []const u8) ?[]const u8 {
    var lines = std.mem.tokenizeScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, key) and line.len > key.len and line[key.len] == '=')
            return line[key.len + 1 ..];
    }
    return null;
}

pub const Snapshot = struct {
    sum: u32 = 0,
    count: u32 = 0,
    online: bool = false,
    charging: bool = false,
    discharging: bool = false,
    full_count: u32 = 0,
    health_sum: u32 = 0,
    health_count: u32 = 0,
    energy_sum: f64 = 0,
    energy_count: u32 = 0,
    cycles: ?u32 = null,
    remaining_minutes: ?u32 = null,

    pub fn add(self: *Snapshot, contents: []const u8) void {
        const kind = field(contents, "POWER_SUPPLY_TYPE") orelse return;
        // Ignore peripheral batteries (mice, keyboards, etc.).
        if (std.mem.eql(u8, field(contents, "POWER_SUPPLY_SCOPE") orelse "", "Device")) return;
        if (!std.mem.eql(u8, kind, "Battery")) {
            if (std.mem.eql(u8, field(contents, "POWER_SUPPLY_ONLINE") orelse "", "1")) self.online = true;
            return;
        }
        if (std.mem.eql(u8, field(contents, "POWER_SUPPLY_PRESENT") orelse "1", "0")) return;
        const raw = std.fmt.parseInt(u32, field(contents, "POWER_SUPPLY_CAPACITY") orelse return, 10) catch return;
        // ACPI computes capacity from ENERGY_NOW / ENERGY_FULL; on a worn pack
        // the firmware's stale "full" estimate makes this read 101% or more.
        // Clamp instead of rejecting, or the battery icon disappears.
        const percent = @min(raw, 100);
        self.sum += percent;
        self.count += 1;
        self.remaining_minutes = estimateMinutes(contents);
        if (std.mem.eql(u8, field(contents, "POWER_SUPPLY_STATUS") orelse "", "Charging")) self.charging = true;
        if (std.mem.eql(u8, field(contents, "POWER_SUPPLY_STATUS") orelse "", "Discharging")) self.discharging = true;
        if (std.mem.eql(u8, field(contents, "POWER_SUPPLY_STATUS") orelse "", "Full")) self.full_count += 1;
        const energy = number(contents, "POWER_SUPPLY_ENERGY_FULL");
        const charge = number(contents, "POWER_SUPPLY_CHARGE_FULL");
        const full = energy orelse charge;
        const design = number(contents, if (energy != null) "POWER_SUPPLY_ENERGY_FULL_DESIGN" else "POWER_SUPPLY_CHARGE_FULL_DESIGN");
        if (full) |f| if (design) |d| {
            if (d > 0 and f > 0) {
                self.health_sum += @intFromFloat(@round(@min(100, f / d * 100)));
                self.health_count += 1;
            }
        };
        // Charge-only drivers need the nominal voltage to express Wh.
        const wh = if (energy) |e| e / 1_000_000 else if (charge) |q| blk: {
            const voltage = number(contents, "POWER_SUPPLY_VOLTAGE_MIN_DESIGN") orelse break :blk null;
            break :blk @as(?f64, q * voltage / 1_000_000_000_000);
        } else null;
        if (wh) |value| if (value > 0) {
            self.energy_sum += value;
            self.energy_count += 1;
        };
        self.cycles = std.fmt.parseInt(u32, field(contents, "POWER_SUPPLY_CYCLE_COUNT") orelse "", 10) catch null;
    }

    pub fn state(self: Snapshot) State {
        return .{
            // Equal-pack average when more than one system battery is present.
            .percent = if (self.count == 0) null else @intCast((self.sum + self.count / 2) / self.count),
            .plugged = self.online or self.charging,
            .charging = self.charging,
            .discharging = self.discharging and !self.charging,
            .full = self.count > 0 and self.full_count == self.count,
            .health = if (self.count > 0 and self.health_count == self.count) @intCast((self.health_sum + self.count / 2) / self.count) else null,
            .full_wh = if (self.count > 0 and self.energy_count == self.count) self.energy_sum else null,
            // Cycle counts belong to a pack; summing them is misleading.
            .cycles = if (self.count == 1) self.cycles else null,
            // A pack's time is not a system estimate with multiple batteries.
            .remaining_minutes = if (self.count == 1) self.remaining_minutes else null,
        };
    }
};

fn number(contents: []const u8, key: []const u8) ?f64 {
    const value = std.fmt.parseInt(u64, field(contents, key) orelse return null, 10) catch return null;
    return @floatFromInt(value);
}

// Driver times are seconds; capacity/rate pairs are micro-Wh/micro-W or
// micro-Ah/micro-A. Keep pairs in the same units, with no voltage guesswork.
fn estimateMinutes(contents: []const u8) ?u32 {
    const status = field(contents, "POWER_SUPPLY_STATUS") orelse return null;
    const charging = std.mem.eql(u8, status, "Charging");
    if (!charging and !std.mem.eql(u8, status, "Discharging")) return null;
    const time_keys = if (charging)
        [_][]const u8{ "POWER_SUPPLY_TIME_TO_FULL_NOW", "POWER_SUPPLY_TIME_TO_FULL_AVG" }
    else
        [_][]const u8{ "POWER_SUPPLY_TIME_TO_EMPTY_NOW", "POWER_SUPPLY_TIME_TO_EMPTY_AVG" };
    for (time_keys) |key| {
        if (number(contents, key)) |seconds| {
            if (minutesFromHours(seconds / 3600)) |minutes| return minutes;
        }
    }
    const pairs = [_][3][]const u8{
        .{ "POWER_SUPPLY_ENERGY_NOW", "POWER_SUPPLY_ENERGY_FULL", "POWER_SUPPLY_POWER_NOW" },
        .{ "POWER_SUPPLY_CHARGE_NOW", "POWER_SUPPLY_CHARGE_FULL", "POWER_SUPPLY_CURRENT_NOW" },
    };
    for (pairs) |keys| {
        const now = number(contents, keys[0]) orelse continue;
        const rate = number(contents, keys[2]) orelse continue;
        if (rate <= 0) continue;
        const remaining = if (charging) (number(contents, keys[1]) orelse continue) - now else now;
        if (minutesFromHours(remaining / rate)) |minutes| return minutes;
    }
    return null;
}

fn minutesFromHours(hours: f64) ?u32 {
    // Reject missing/invalid rates and avoid overflowing on broken firmware.
    const minutes = @ceil(hours * 60);
    if (!std.math.isFinite(minutes) or minutes <= 0 or minutes > std.math.maxInt(u32)) return null;
    return @intFromFloat(minutes);
}

pub fn read(io: std.Io, allocator: std.mem.Allocator) State {
    var dir = std.Io.Dir.cwd().openDir(io, "/sys/class/power_supply", .{ .iterate = true }) catch return .{};
    defer dir.close(io);
    var snapshot: Snapshot = .{};
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        var path_buf: [512]u8 = undefined;
        // A HID peripheral battery's uevent can send a synchronous GET_REPORT
        // to the device; `scope` is static, so check it before reading that.
        const scope_path = std.fmt.bufPrint(&path_buf, "{s}/scope", .{entry.name}) catch continue;
        var scope_buf: [16]u8 = undefined;
        if (dir.readFile(io, scope_path, &scope_buf)) |scope| {
            if (std.mem.eql(u8, std.mem.trimEnd(u8, scope, "\n"), "Device")) continue;
        } else |_| {}
        const path = std.fmt.bufPrint(&path_buf, "{s}/uevent", .{entry.name}) catch continue;
        const contents = dir.readFileAlloc(io, path, allocator, .limited(16384)) catch continue;
        defer allocator.free(contents);
        snapshot.add(contents);
    }
    return snapshot.state();
}

/// Nonblocking socket on the kernel's uevent multicast group; `null` leaves
/// only the minute poll. Receiving needs no privileges, and sending to the
/// group does, so nothing unprivileged can fake these (they only trigger a
/// sysfs read anyway).
pub fn openUeventSocket() ?std.posix.fd_t {
    const rc = linux.socket(linux.AF.NETLINK, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK, linux.NETLINK.KOBJECT_UEVENT);
    // Raw syscalls return -errno; std.posix.errno expects libc's -1/errno.
    if (linux.errno(rc) != .SUCCESS) return null;
    const fd: std.posix.fd_t = @intCast(rc);
    const addr: linux.sockaddr.nl = .{ .pid = 0, .groups = 1 };
    if (linux.errno(linux.bind(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.nl))) != .SUCCESS) {
        _ = std.posix.system.close(fd);
        return null;
    }
    return fd;
}

/// Empties the socket. True when any message could change `read`'s result,
/// including an overflow that may have dropped one.
pub fn drainUevents(fd: std.posix.fd_t) bool {
    var relevant = false;
    var buf: [8192]u8 = undefined;
    while (true) {
        const rc = linux.recvfrom(fd, &buf, buf.len, 0, null, null);
        switch (linux.errno(rc)) {
            .SUCCESS => if (isSystemPowerSupplyUevent(buf[0..rc])) {
                relevant = true;
            },
            .INTR => {},
            .NOBUFS => relevant = true,
            else => return relevant,
        }
    }
}

/// Kernel uevents are `action@devpath` then NUL-separated KEY=VALUE pairs.
/// Peripheral batteries are ignored by `read`, so their events are too.
pub fn isSystemPowerSupplyUevent(msg: []const u8) bool {
    var fields = std.mem.splitScalar(u8, msg, 0);
    if (std.mem.indexOfScalar(u8, fields.first(), '@') == null) return false;
    var power_supply = false;
    while (fields.next()) |kv| {
        if (std.mem.eql(u8, kv, "SUBSYSTEM=power_supply")) power_supply = true;
        if (std.mem.eql(u8, kv, "POWER_SUPPLY_SCOPE=Device")) return false;
    }
    return power_supply;
}

test {
    _ = @import("battery_tests.zig");
}
