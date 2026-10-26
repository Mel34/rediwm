//! Shared geometry for the tab controls and their hover feedback.
const c = @import("../files/c.zig").api;
const ui = @import("ui").cairo;
const theme = @import("ui").theme;
const button = @import("ui").widgets.button;
const Rect = @import("ui").context_menu.Rect;
const app = @import("app.zig");
const App = app.App;
const SearchControl = @import("app_search.zig").Control;

pub fn tabCloseBox(_: *const App, index: usize) Rect {
    return .{ .x = @as(f64, @floatFromInt(index)) * app.tab_w + app.tab_w - 36, .y = 2, .w = 34, .h = 34 };
}

pub fn newButtonBox(self: *const App) Rect {
    return .{ .x = self.tabRight(), .y = 2, .w = 36, .h = 34 };
}

pub fn menuButtonBox(self: *const App) Rect {
    return .{ .x = @as(f64, @floatFromInt(self.w)) - 38, .y = 2, .w = 36, .h = 34 };
}

const Hover = union(enum) { none, close: usize, new, menu, search: SearchControl, dialog: usize };

pub fn hoverTarget(self: *App) Hover {
    if (self.close_tab != null) {
        const x = (@as(f64, @floatFromInt(self.w)) - 420) / 2;
        const y = (@as(f64, @floatFromInt(self.h)) - 170) / 2;
        for ([_]Rect{
            .{ .x = x + 20, .y = y + 112, .w = 115, .h = 38 },
            .{ .x = x + 145, .y = y + 112, .w = 125, .h = 38 },
            .{ .x = x + 280, .y = y + 112, .w = 120, .h = 38 },
        }, 0..) |box, i| if (box.contains(self.px, self.py)) return .{ .dialog = i };
        return .none;
    }
    if (self.menu_open) return .none;
    if (self.find_open) if (self.searchHit(self.px, self.py)) |hit| return .{ .search = hit };
    if (self.newButtonBox().contains(self.px, self.py)) return .new;
    if (!self.has_titlebar and self.menuButtonBox().contains(self.px, self.py)) return .menu;
    for (self.first_tab..self.tabs.items.len) |i| {
        const index = i - self.first_tab;
        if (@as(f64, @floatFromInt(index + 1)) * app.tab_w > self.tabRight()) break;
        if (self.tabCloseBox(index).contains(self.px, self.py)) return .{ .close = i };
    }
    return .none;
}

pub fn paintIcon(self: *App, cr: *c.cairo_t, box: Rect, icon: @import("ui").layout.IconId, label: []const u8, selected: bool) void {
    var layer = ui.Layer.begin(cr, .{ .x = @floatCast(box.x), .y = @floatCast(box.y), .w = @floatCast(box.w), .h = @floatCast(box.h) }) orelse return;
    defer layer.finish();
    layer.renderer.palette = theme.shellPalette();
    button.paint(&layer.renderer, layer.local(), .{ .label = label, .icon = icon, .variant = .ghost, .size = .sm }, .{
        .selected = selected,
        .pointer = if (!self.menu_open and self.close_tab == null and box.contains(self.px, self.py)) .hover else .idle,
    });
}
