//! xdg-output metadata uses the same header-backed OutputLayout as the
//! compositor. wlroots owns these structs; omit their private listeners.
const wl = @import("wayland").server.wl;
const c = @import("c.zig").c;
const assertSameLayout = @import("signal.zig").assertSameLayout;
const assertFieldOffset = @import("signal.zig").assertFieldOffset;

pub fn Types(comptime OutputLayout: type) type {
    return struct {
        pub const XdgOutputV1 = extern struct {
            manager: *XdgOutputManagerV1,
            resources: wl.list.Head(wl.Resource, null),
            link: wl.list.Link,
            layout_output: *OutputLayout.Output,
            x: i32,
            y: i32,
            width: i32,
            height: i32,

            comptime {
                for (@typeInfo(XdgOutputV1).@"struct".fields) |field| {
                    assertFieldOffset(XdgOutputV1, c.wlr_xdg_output_v1, field.name);
                    assertSameLayout(field.type, @FieldType(c.wlr_xdg_output_v1, field.name));
                }
            }
        };

        pub const XdgOutputManagerV1 = extern struct {
            global: *wl.Global,
            layout: *OutputLayout,
            outputs: wl.list.Head(XdgOutputV1, .link),
            events: extern struct {
                destroy: wl.Signal(*XdgOutputManagerV1),
            },

            pub fn create(server: *wl.Server, layout: *OutputLayout) !*XdgOutputManagerV1 {
                const raw = c.wlr_xdg_output_manager_v1_create(@ptrCast(server), @ptrCast(layout));
                return @as(?*XdgOutputManagerV1, @ptrCast(raw)) orelse error.OutOfMemory;
            }

            comptime {
                const Real = c.wlr_xdg_output_manager_v1;
                for (@typeInfo(XdgOutputManagerV1).@"struct".fields) |field| {
                    assertFieldOffset(XdgOutputManagerV1, Real, field.name);
                    assertSameLayout(field.type, @FieldType(Real, field.name));
                }
                const Events = @FieldType(XdgOutputManagerV1, "events");
                assertFieldOffset(Events, @FieldType(Real, "events"), "destroy");
                assertSameLayout(@FieldType(Events, "destroy"), c.wl_signal);
            }
        };
    };
}
