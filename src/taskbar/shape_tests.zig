const std = @import("std");
const wlr = @import("wlroots");
const shape = @import("shape.zig");
const place = shape.place;
const flush = shape.flush;
const min_width = shape.min_width;
const cornerInset = shape.cornerInset;
const effectiveRadius = shape.effectiveRadius;
const Look = shape.Look;
const background = shape.background;

const TestColor = struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 0,

    pub fn over(source: TestColor, destination: TestColor) TestColor {
        const alpha = source.a + destination.a * (1 - source.a);
        if (alpha == 0) return .{};
        return .{
            .r = (source.r * source.a + destination.r * destination.a * (1 - source.a)) / alpha,
            .g = (source.g * source.a + destination.g * destination.a * (1 - source.a)) / alpha,
            .b = (source.b * source.a + destination.b * destination.a * (1 - source.a)) / alpha,
            .a = alpha,
        };
    }
    pub fn scaled(color: TestColor, alpha: f32) TestColor {
        return .{ .r = color.r, .g = color.g, .b = color.b, .a = std.math.clamp(color.a * alpha, 0, 1) };
    }
};

test "the bar is centred, keeps its gap on the edge it sits on and never gets too short" {
    const output: wlr.Box = .{ .x = 100, .y = 50, .width = 1920, .height = 1080 };
    const flat = place(output, .{ .height = 44 });
    try std.testing.expectEqual(wlr.Box{ .x = 100, .y = 50 + 1080 - 44, .width = 1920, .height = 44 }, flat.box);
    try std.testing.expectEqual(@as(i32, 44), flat.reserved);

    const floating = place(output, .{ .height = 44, .edge_gap = 12, .length = 60 });
    try std.testing.expectEqual(wlr.Box{ .x = 100 + 384, .y = 50 + 1080 - 44 - 12, .width = 1152, .height = 44 }, floating.box);
    try std.testing.expectEqual(@as(i32, 56), floating.reserved);

    const top = place(output, .{ .height = 44, .edge_gap = 12, .length = 60, .top = true });
    try std.testing.expectEqual(@as(i32, 50 + 12), top.box.y);
    try std.testing.expectEqual(@as(i32, 56), top.reserved);

    inline for (.{ .left, .center, .right }, .{ 100, 484, 868 }) |alignment, x| {
        for ([_]bool{ false, true }) |at_top| {
            const aligned = place(output, .{ .height = 44, .edge_gap = 12, .length = 60, .alignment = alignment, .top = at_top });
            try std.testing.expectEqual(@as(i32, x), aligned.box.x);
            try std.testing.expectEqual(floating.box.width, aligned.box.width);
            try std.testing.expectEqual(if (at_top) top.box.y else floating.box.y, aligned.box.y);
            try std.testing.expectEqual(floating.reserved, aligned.reserved);
            try std.testing.expectEqual(flat.box, place(output, .{ .height = 44, .alignment = alignment }).box);
        }
    }

    // Shorter than the items need, or than the output is wide.
    try std.testing.expectEqual(min_width, place(output, .{ .height = 44, .length = 20 }).box.width);
    const narrow: wlr.Box = .{ .x = 0, .y = 0, .width = 300, .height = 600 };
    try std.testing.expectEqual(@as(i32, 300), place(narrow, .{ .height = 44, .length = 50 }).box.width);
    // Out-of-range asks fall back into range instead of leaving the output.
    try std.testing.expectEqual(@as(i32, 1920), place(output, .{ .height = 44, .length = 400 }).box.width);
    try std.testing.expectEqual(@as(i32, 1080), place(output, .{ .height = 44, .edge_gap = 5000 }).reserved);
}

test "only the original bar is flush" {
    const output: wlr.Box = .{ .x = 0, .y = 0, .width = 1920, .height = 1080 };
    const bottom = place(output, .{ .height = 44 }).box;
    try std.testing.expect(flush(output, bottom, 0));
    try std.testing.expect(flush(output, place(output, .{ .height = 44, .top = true }).box, 0));
    try std.testing.expect(!flush(output, bottom, 8));
    try std.testing.expect(!flush(output, place(output, .{ .height = 44, .edge_gap = 6 }).box, 0));
    try std.testing.expect(!flush(output, place(output, .{ .height = 44, .length = 80 }).box, 0));
}

test "items clear a rounded end by exactly what the curve takes" {
    try std.testing.expectEqual(@as(i32, 0), cornerInset(0, 4));
    // Margin as tall as the radius: the item's corner is past the curve.
    try std.testing.expectEqual(@as(i32, 0), cornerInset(6, 6));
    // A pill 44 high: an item 4 from the top starts about 9.4 px in.
    try std.testing.expectEqual(@as(i32, 10), cornerInset(22, 4));
    try std.testing.expectEqual(@as(f32, 22), effectiveRadius(80, 44));
    try std.testing.expectEqual(@as(f32, 0), effectiveRadius(-3, 44));
    // The reported inset really does put the item corner inside the arc.
    const r: f32 = 22;
    const inset: f32 = @floatFromInt(cornerInset(r, 4));
    try std.testing.expect((r - inset) * (r - inset) + (r - 4) * (r - 4) <= r * r);
}

test "the flush background is the original fill and hairline, on the side facing the windows" {
    const fill: TestColor = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 0.96 };
    const line: TestColor = .{ .r = 1, .g = 1, .b = 1, .a = 0.06 };
    const bottom: Look = .{ .width = 400, .height = 44, .radius = 0, .outline = 1, .flush = true, .top = false };
    try std.testing.expectEqualDeep(line.over(fill), background(TestColor, bottom, 100, 0.5, 1, fill, line));
    try std.testing.expectEqualDeep(fill, background(TestColor, bottom, 100, 1.5, 1, fill, line));
    var top = bottom;
    top.top = true;
    try std.testing.expectEqualDeep(fill, background(TestColor, top, 100, 0.5, 1, fill, line));
    try std.testing.expectEqualDeep(line.over(fill), background(TestColor, top, 100, 43.5, 1, fill, line));
    var bare = bottom;
    bare.outline = 0;
    try std.testing.expectEqualDeep(fill, background(TestColor, bare, 100, 0.5, 1, fill, line));
}

fn expectColor(expected: TestColor, actual: TestColor) !void {
    inline for (.{ "r", "g", "b", "a" }) |channel| try std.testing.expectApproxEqAbs(@field(expected, channel), @field(actual, channel), 1e-5);
}

test "a floating background rounds its corners and wears its outline all round" {
    const fill: TestColor = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 0.9 };
    const line: TestColor = .{ .r = 1, .g = 0, .b = 0, .a = 0.5 };
    const look: Look = .{ .width = 400, .height = 44, .radius = 22, .outline = 2, .flush = false, .top = false };
    // The corner is cut away, the middle is plain fill, the rim carries the outline.
    try std.testing.expectEqual(@as(f32, 0), background(TestColor, look, 0.5, 0.5, 1, fill, line).a);
    try expectColor(fill, background(TestColor, look, 200, 22, 1, fill, line));
    try expectColor(line.over(fill), background(TestColor, look, 200, 0.5, 1, fill, line));
    try expectColor(line.over(fill), background(TestColor, look, 200, 43.5, 1, fill, line));
    try expectColor(line.over(fill), background(TestColor, look, 0.5, 22, 1, fill, line));
    // Square but floating (only a gap or a length): the corners stay filled.
    var square = look;
    square.radius = 0;
    try std.testing.expect(background(TestColor, square, 1, 1, 1, fill, line).a > 0.9);
    // The ramp is antialiased across the curve.
    const edge = background(TestColor, look, 6.4, 6.4, 1, fill, line).a;
    try std.testing.expect(edge > 0 and edge < 1);
}
