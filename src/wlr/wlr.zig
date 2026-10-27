//! Facade over wlroots: the same `wlr.*` names callers already use,
//! migrated off zig-wlroots one subsystem at a time onto a module backed
//! directly by @cImport against the real wlroots headers (see the
//! "zig-wlroots" note in the top-level AGENTS.md for why, and
//! docs/agent-notes for the migration order). Everything below that
//! hasn't migrated yet forwards straight to the real zig-wlroots
//! dependency, imported here as `old`, so callers never see a difference
//! until a type actually moves off it.
const old = @import("old");

const output_power = @import("output_power.zig").Types(Output);
pub const OutputPowerManagerV1 = output_power.OutputPowerManagerV1;
pub const OutputPowerV1 = output_power.OutputPowerV1;

const idle_notify = @import("idle_notify.zig").Types(old.Seat);
pub const IdleNotifierV1 = idle_notify.IdleNotifierV1;

const idle_inhibit = @import("idle_inhibit.zig").Types(old.Surface);
pub const IdleInhibitManagerV1 = idle_inhibit.IdleInhibitManagerV1;
pub const IdleInhibitorV1 = idle_inhibit.IdleInhibitorV1;

const kb_shortcuts_inhibit = @import("keyboard_shortcuts_inhibit.zig").Types(old.Surface, old.Seat);
pub const KeyboardShortcutsInhibitManagerV1 = kb_shortcuts_inhibit.KeyboardShortcutsInhibitManagerV1;
pub const KeyboardShortcutsInhibitorV1 = kb_shortcuts_inhibit.KeyboardShortcutsInhibitorV1;

const security_context = @import("security_context.zig");
pub const SecurityContextManagerV1 = security_context.SecurityContextManagerV1;
pub const SecurityContextV1State = security_context.SecurityContextV1State;

const fractional_scale = @import("fractional_scale.zig").Types(old.Surface);
pub const FractionalScaleManagerV1 = fractional_scale.FractionalScaleManagerV1;

const relative_pointer = @import("relative_pointer.zig").Types(old.Seat);
pub const RelativePointerManagerV1 = relative_pointer.RelativePointerManagerV1;
pub const RelativePointerV1 = relative_pointer.RelativePointerV1;

const pointer_constraints = @import("pointer_constraints.zig").Types(old.Surface, old.Seat);
pub const PointerConstraintsV1 = pointer_constraints.PointerConstraintsV1;
pub const PointerConstraintV1 = pointer_constraints.PointerConstraintV1;

const output_mod = @import("output.zig").Types(old.Backend, old.Renderer, old.Allocator, old.Buffer, old.ColorTransform);
pub const Output = output_mod.Output;
pub const OutputCursor = output_mod.OutputCursor;

const output_layout_mod = @import("output_layout.zig").Types(Output);
pub const OutputLayout = output_layout_mod.OutputLayout;

// Box/FBox/Edges: OutputLayout.getBox was their main blocker (45 call
// sites) and just migrated above. The remaining crossings
// (Surface.getBufferSourceBox, XdgPopup.unconstrainFromBox,
// InputPopupSurfaceV2.sendTextInputRectangle, XdgToplevel.setTiled) are
// single-digit call counts against types that haven't migrated, each
// handled with a `@ptrCast` at that one call site instead of waiting for
// those types too -- see assertSameLayout(Box, old.Box) below, which is
// exactly what makes that cast provably safe.
pub const Box = @import("box.zig").Box;
pub const FBox = @import("box.zig").FBox;
pub const Edges = @import("edges.zig").Edges;

comptime {
    const assertSameLayout = @import("signal.zig").assertSameLayout;
    assertSameLayout(Box, old.Box);
    assertSameLayout(FBox, old.FBox);
    assertSameLayout(Edges, old.Edges);
}

/// Backend, ForeignToplevelHandleV1 and anything else still on `old`
/// that embeds `*wlr.Output` in its own signature (a signal payload, a
/// method parameter) is pinned to zig-wlroots's own Output type, not
/// ours, for exactly that crossing -- see Server.zig's `new_output`
/// listener and foreign_toplevel.zig's `outputEnter`/`outputLeave` for
/// the two places that needs a `@ptrCast`. Exposed here rather than
/// scattered `@import("old")`s so every such crossing reads the same way.
pub const zig_wlroots = old;

pub const AddonSet = old.AddonSet;
pub const Allocator = old.Allocator;
pub const Backend = old.Backend;
pub const Buffer = old.Buffer;
pub const ColorTransform = old.ColorTransform;
pub const Compositor = old.Compositor;
pub const Cursor = old.Cursor;
pub const CursorShapeManagerV1 = old.CursorShapeManagerV1;
pub const DataControlManagerV1 = old.DataControlManagerV1;
pub const DataDeviceManager = old.DataDeviceManager;
pub const DataSource = old.DataSource;
pub const Drag = old.Drag;
pub const DrmFormat = old.DrmFormat;
pub const DrmSyncobjTimeline = old.DrmSyncobjTimeline;
pub const ExtDataControlManagerV1 = old.ExtDataControlManagerV1;
pub const ExtForeignToplevelHandleV1 = old.ExtForeignToplevelHandleV1;
pub const ExtForeignToplevelImageCaptureSourceManagerV1 = old.ExtForeignToplevelImageCaptureSourceManagerV1;
pub const ExtForeignToplevelListV1 = old.ExtForeignToplevelListV1;
pub const ExtImageCaptureSourceV1 = old.ExtImageCaptureSourceV1;
pub const ExtImageCopyCaptureFrameV1 = old.ExtImageCopyCaptureFrameV1;
pub const ExtImageCopyCaptureManagerV1 = old.ExtImageCopyCaptureManagerV1;
pub const ExtImageCopyCaptureSessionV1 = old.ExtImageCopyCaptureSessionV1;
pub const ExtOutputImageCaptureSourceManagerV1 = old.ExtOutputImageCaptureSourceManagerV1;
pub const ForeignToplevelHandleV1 = old.ForeignToplevelHandleV1;
pub const ForeignToplevelManagerV1 = old.ForeignToplevelManagerV1;
pub const InputDevice = old.InputDevice;
pub const InputMethodManagerV2 = old.InputMethodManagerV2;
pub const InputMethodV2 = old.InputMethodV2;
pub const InputPopupSurfaceV2 = old.InputPopupSurfaceV2;
pub const Keyboard = old.Keyboard;
pub const LayerShellV1 = old.LayerShellV1;
pub const LayerSurfaceV1 = old.LayerSurfaceV1;
pub const LinuxDmabufV1 = old.LinuxDmabufV1;
pub const LinuxDrmSyncobjManagerV1 = old.LinuxDrmSyncobjManagerV1;
pub const OutputConfigurationV1 = old.OutputConfigurationV1;
pub const OutputHeadV1 = old.OutputHeadV1;
pub const OutputManagerV1 = old.OutputManagerV1;
pub const Pointer = old.Pointer;
pub const PointerGesturesV1 = old.PointerGesturesV1;
pub const Presentation = old.Presentation;
pub const PrimarySelectionDeviceManagerV1 = old.PrimarySelectionDeviceManagerV1;
pub const RenderPass = old.RenderPass;
pub const Renderer = old.Renderer;
pub const Scene = old.Scene;
pub const ScreencopyFrameV1 = old.ScreencopyFrameV1;
pub const ScreencopyManagerV1 = old.ScreencopyManagerV1;
pub const Seat = old.Seat;
pub const Session = old.Session;
pub const SessionLockManagerV1 = old.SessionLockManagerV1;
pub const SessionLockSurfaceV1 = old.SessionLockSurfaceV1;
pub const SessionLockV1 = old.SessionLockV1;
pub const SinglePixelBufferManagerV1 = old.SinglePixelBufferManagerV1;
pub const Subcompositor = old.Subcompositor;
pub const Surface = old.Surface;
pub const Swapchain = old.Swapchain;
pub const Switch = old.Switch;
pub const Tablet = old.Tablet;
pub const TabletManagerV2 = old.TabletManagerV2;
pub const TabletPad = old.TabletPad;
pub const TabletTool = old.TabletTool;
pub const TabletV2Tablet = old.TabletV2Tablet;
pub const TabletV2TabletPad = old.TabletV2TabletPad;
pub const TabletV2TabletTool = old.TabletV2TabletTool;
pub const TextInputManagerV3 = old.TextInputManagerV3;
pub const TextInputV3 = old.TextInputV3;
pub const Texture = old.Texture;
pub const Touch = old.Touch;
pub const Viewporter = old.Viewporter;
pub const VirtualKeyboardManagerV1 = old.VirtualKeyboardManagerV1;
pub const VirtualKeyboardV1 = old.VirtualKeyboardV1;
pub const VirtualPointerManagerV1 = old.VirtualPointerManagerV1;
pub const XcursorManager = old.XcursorManager;
pub const XdgActivationTokenV1 = old.XdgActivationTokenV1;
pub const XdgActivationV1 = old.XdgActivationV1;
pub const XdgDecorationManagerV1 = old.XdgDecorationManagerV1;
pub const XdgOutputManagerV1 = old.XdgOutputManagerV1;
pub const XdgPopup = old.XdgPopup;
pub const XdgShell = old.XdgShell;
pub const XdgSurface = old.XdgSurface;
pub const XdgToplevel = old.XdgToplevel;
pub const XdgToplevelDecorationV1 = old.XdgToplevelDecorationV1;
pub const Xwayland = old.Xwayland;
pub const XwaylandSurface = old.XwaylandSurface;

pub const color = old.color;
pub const config = old.config;
pub const log = old.log;
pub const region = old.region;
