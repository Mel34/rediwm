//! The single @cImport boundary for every wlroots C header the facade in
//! this directory needs. One pass keeps translate-c's generated type
//! identities consistent across files, mirroring zig-wlroots's own
//! single-root `wlroots.zig` import. Add one @cInclude per header as a
//! subsystem migrates; never @cImport a header a second time elsewhere.
pub const c = @cImport({
    @cDefine("WLR_USE_UNSTABLE", {});
    @cInclude("wlr/util/box.h");
    @cInclude("wlr/util/edges.h");
    @cInclude("wlr/types/wlr_output_power_management_v1.h");
    @cInclude("wlr/types/wlr_idle_notify_v1.h");
    @cInclude("wlr/types/wlr_idle_inhibit_v1.h");
    @cInclude("wlr/types/wlr_keyboard_shortcuts_inhibit_v1.h");
    @cInclude("wlr/types/wlr_security_context_v1.h");
    @cInclude("wlr/types/wlr_fractional_scale_v1.h");
    @cInclude("wlr/types/wlr_relative_pointer_v1.h");
});
