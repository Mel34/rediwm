//! The bar as a shape: where it sits on its output, how far its items keep
//! from rounded ends, and the pixels of its background. Pure arithmetic, so
//! every floating variant is checked without a compositor.
const std = @import("std");
const wlr = @import("wlroots");
const sdf = @import("ui").sdf;

/// The narrowest a bar is drawn however short it is asked to be: the start
/// button, a few icons and the clock still have to fit.
pub const min_width: i32 = 420;

pub const Spec = struct {
    height: i32,
    /// Logical px between the bar and the output edge it sits on.
    edge_gap: i32 = 0,
    /// Percent of the output's width.
    length: f32 = 100,
    alignment: @import("config").types.TaskbarAlignment = .center,
    radius: f32 = 0,
    top: bool = false,
};

pub const Placement = struct {
    box: wlr.Box,
    /// What the bar claims from the output edge: its height and its gap.
    reserved: i32,
};

pub fn place(output: wlr.Box, spec: Spec) Placement {
    const percent = std.math.clamp(spec.length, 20, 100);
    const wanted: i32 = @intFromFloat(@round(@as(f32, @floatFromInt(output.width)) * percent / 100));
    const width = std.math.clamp(wanted, @min(output.width, min_width), output.width);
    const gap = std.math.clamp(spec.edge_gap, 0, @max(0, output.height - spec.height));
    return .{
        .box = .{
            .x = output.x + switch (spec.alignment) {
                .left => @as(i32, 0),
                .center => @divTrunc(output.width - width, 2),
                .right => output.width - width,
            },
            .y = if (spec.top) output.y + gap else output.y + output.height - spec.height - gap,
            .width = width,
            .height = spec.height,
        },
        .reserved = spec.height + gap,
    };
}

/// Flush means the original bar: edge to edge, on the output's edge, square.
/// It keeps its single hairline on the side facing the windows.
pub fn flush(output: wlr.Box, placed: wlr.Box, radius: f32) bool {
    return radius <= 0 and placed.width >= output.width and placed.x == output.x and
        (placed.y == output.y or placed.y + placed.height == output.y + output.height);
}

/// A corner can't be rounder than a pill.
pub fn effectiveRadius(radius: f32, height: i32) f32 {
    return @max(0, @min(radius, @as(f32, @floatFromInt(height)) / 2));
}

/// How far from an end of the bar an item has to start to stay inside the
/// curve, when its near edge is `margin` from the bar's top or bottom.
pub fn cornerInset(radius: f32, margin: f32) i32 {
    const rise = radius - margin;
    if (radius <= 0 or rise <= 0) return 0;
    return @intFromFloat(@ceil(radius - @sqrt(radius * radius - rise * rise)));
}

pub const Look = struct {
    /// Logical size of the raster the pixel is sampled in.
    width: f32,
    height: f32,
    radius: f32,
    outline: f32,
    flush: bool,
    top: bool,
};

/// One pixel of the bar's background at logical `px`, `py` of its raster.
/// `C` is a straight-alpha colour with `over` and `scaled`. The outline is
/// composited over the fill, never replacing it: both are translucent.
pub fn background(comptime C: type, look: Look, px: f32, py: f32, scale: f32, fill: C, outline: C) C {
    if (look.flush) {
        const edge = if (look.top) py >= look.height - look.outline else py < look.outline;
        return if (edge) outline.over(fill) else fill;
    }
    const covered = coverage(sdf.sdRoundedBox(px, py, 0, 0, look.width, look.height, look.radius), scale);
    if (covered <= 0) return fill.scaled(0);
    const o = look.outline;
    const inside = if (o <= 0) 1 else coverage(sdf.sdRoundedBox(px, py, o, o, look.width - 2 * o, look.height - 2 * o, @max(0, look.radius - o)), scale);
    return outline.scaled(1 - inside).over(fill).scaled(covered);
}

fn coverage(distance: f32, scale: f32) f32 {
    return std.math.clamp(0.5 - distance * scale, 0, 1);
}

test {
    _ = @import("shape_tests.zig");
}
