//! Retype the C declarations at the single header boundary, checking their
//! ABI before exposing Zig's protocol enums, lists and method-friendly types.
const std = @import("std");

pub fn bind(comptime F: type, comptime function: anytype) F {
    @setEvalBranchQuota(100000);
    comptime assertFunction(F, @TypeOf(function));
    const signature = @typeInfo(F).@"fn";
    const params = signature.params;
    const Return = signature.return_type.?;
    // Actual function declarations preserve Zig's method-call syntax. A cast
    // function pointer alone would require a second implicit dereference.
    return switch (params.len) {
        0 => struct {
            fn call() callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))();
            }
        }.call,
        1 => struct {
            fn call(a0: params[0].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0);
            }
        }.call,
        2 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1);
            }
        }.call,
        3 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2);
            }
        }.call,
        4 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3);
            }
        }.call,
        5 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4);
            }
        }.call,
        6 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5);
            }
        }.call,
        7 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?, a6: params[6].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5, a6);
            }
        }.call,
        8 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?, a6: params[6].type.?, a7: params[7].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5, a6, a7);
            }
        }.call,
        9 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?, a6: params[6].type.?, a7: params[7].type.?, a8: params[8].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5, a6, a7, a8);
            }
        }.call,
        10 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?, a6: params[6].type.?, a7: params[7].type.?, a8: params[8].type.?, a9: params[9].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
            }
        }.call,
        11 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?, a6: params[6].type.?, a7: params[7].type.?, a8: params[8].type.?, a9: params[9].type.?, a10: params[10].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
            }
        }.call,
        12 => struct {
            fn call(a0: params[0].type.?, a1: params[1].type.?, a2: params[2].type.?, a3: params[3].type.?, a4: params[4].type.?, a5: params[5].type.?, a6: params[6].type.?, a7: params[7].type.?, a8: params[8].type.?, a9: params[9].type.?, a10: params[10].type.?, a11: params[11].type.?) callconv(.c) Return {
                return @as(*const F, @ptrCast(&function))(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
            }
        }.call,
        else => @compileError("Add a wrapper arity for this wlroots declaration"),
    };
}

fn assertFunction(comptime A: type, comptime B: type) void {
    const a = @typeInfo(A).@"fn";
    const b = @typeInfo(B).@"fn";
    if (!std.meta.eql(a.calling_convention, b.calling_convention) or
        a.is_var_args != b.is_var_args or a.params.len != b.params.len)
        @compileError("C function signature changed: " ++ @typeName(A) ++ " / " ++ @typeName(B));
    for (a.params, b.params) |ap, bp| assertValue(ap.type.?, bp.type.?);
    assertValue(a.return_type.?, b.return_type.?);
}

fn pointerChild(comptime T: type) ?type {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.child,
        .optional => |o| switch (@typeInfo(o.child)) {
            .pointer => |p| p.child,
            else => null,
        },
        else => null,
    };
}

pub fn assertValue(comptime A: type, comptime B: type) void {
    if (A == B) return;
    assertSize(A, B);
    if (pointerChild(A)) |ap| {
        const bp = pointerChild(B) orelse @compileError("C pointer changed: " ++ @typeName(B));
        if (@typeInfo(ap) == .@"fn" or @typeInfo(bp) == .@"fn") {
            if (@typeInfo(ap) != .@"fn" or @typeInfo(bp) != .@"fn")
                @compileError("C callback changed");
            assertFunction(ap, bp);
        }
        return;
    }
    const ai = @typeInfo(A);
    const bi = @typeInfo(B);
    switch (ai) {
        .@"enum" => |a| assertValue(a.tag_type, B),
        .int => switch (bi) {
            .int => {},
            .@"enum" => |b| assertValue(A, b.tag_type),
            .@"struct" => |b| if (b.layout != .@"packed") {
                @compileError("C integer changed");
            },
            else => @compileError("C integer changed: " ++ @typeName(B)),
        },
        .@"struct" => |a| {
            if (a.layout == .@"packed") {
                if (bi != .int and bi != .@"struct") @compileError("C bitmask changed");
            } else {
                assertFields(A, B);
            }
        },
        .array => |a| {
            const b = bi.array;
            if (a.len != b.len) @compileError("C array length changed");
            assertValue(a.child, b.child);
        },
        .@"union" => {}, // Union alternatives are checked by their owning adapter.
        .void, .float, .bool => if (std.meta.activeTag(ai) != std.meta.activeTag(bi)) {
            @compileError("C scalar changed");
        },
        else => @compileError("Unsupported C ABI type: " ++ @typeName(A)),
    }
}

fn assertSize(comptime A: type, comptime B: type) void {
    if (@sizeOf(A) != @sizeOf(B) or @alignOf(A) != @alignOf(B))
        @compileError("C ABI size/alignment changed: " ++ @typeName(A) ++ " / " ++ @typeName(B));
}

/// Check every represented field, including nested events and inline state.
/// A wlroots-owned object may omit its private tail. Use assertLayout for
/// objects allocated or passed by value by the compositor.
pub fn assertFields(comptime A: type, comptime B: type) void {
    @setEvalBranchQuota(100000);
    const fields = @typeInfo(A).@"struct".fields;
    // zig-wayland wraps wl_list in a typed Head with one embedded Link.
    if (fields.len == 1 and std.mem.eql(u8, fields[0].name, "link") and
        @hasField(B, "prev") and @hasField(B, "next"))
    {
        if (@offsetOf(A, "link") != 0) @compileError("Wayland list wrapper moved");
        assertValue(fields[0].type, B);
        return;
    }
    for (fields) |field| {
        if (!@hasField(B, field.name))
            @compileError("C field missing: " ++ @typeName(B) ++ "." ++ field.name);
        if (@offsetOf(A, field.name) != @offsetOf(B, field.name))
            @compileError("C field offset changed: " ++ @typeName(A) ++ "." ++ field.name);
        assertValue(field.type, @FieldType(B, field.name));
    }
}

pub fn assertLayout(comptime A: type, comptime B: type) void {
    assertSize(A, B);
    assertFields(A, B);
}
