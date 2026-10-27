# src/wlr: the in-tree wlroots facade

Replaces `zig-wlroots` one subsystem at a time with a module backed
directly by `@cImport` against the real wlroots headers, because
hand-mirroring wlroots' C ABI by hand (what zig-wlroots does) both lags
new Zig releases and risks silent layout bugs (`wlr.Pointer` was 8 bytes
short at one point, see the top-level AGENTS.md). `@cImport` ships inside
the compiler, so it tracks whatever Zig version is building the project
automatically, and the compiler reads the real struct layout instead of a
hand-typed copy of it.

## How it's wired

`wlr.zig` is what `@import("wlroots")` resolves to (set in `build.zig`).
It re-exports every `wlr.*` name the rest of the compositor uses. A
migrated type comes from this directory; everything else forwards
straight to the real zig-wlroots dependency, imported here as `old`
(`build.zig`'s `wlroots_dep`, still fetched via `build.zig.zon`). Callers
never see which side a type comes from.

`c.zig` holds the single `@cImport` block every migrated file imports
from. Keep it one block: translate-c assigns each header its own type
identities per `@cImport` call, so two separate `@cImport`s of the same
header produce two incompatible Zig types.

## Adding a migrated type

1. Add its header to `c.zig`'s `@cImport`.
2. If the type is a plain value with no pointers (`Box`, `Edges`-shaped
   things): redeclare its fields so Zig's method-call sugar works
   (`c.wlr_foo` is a foreign type you can't attach `pub fn`s to from this
   file), call the real `wlr_foo_*` functions from the methods, and add
   `assertFieldOffset`/`assertSameLayout` (`signal.zig`) for every field —
   see `box.zig`.
3. If it has a `wl_signal`/`wl_resource`/`wl_list` field: same
   redeclare-and-assert approach, but retype those fields as
   zig-wayland's `wl.Signal(T)` / `wl.Resource` / `wl.list.Head(T, field)`
   instead of the raw `@cImport` type, so `.add()`/`.get()`/`.emit()` work
   on the result. This is safe only because `struct wl_signal` is one
   `wl_list` and `struct wl_listener` is a `wl_list` plus a function
   pointer, and always will be — that's what `assertSameLayout` is
   checking, not a formality. Omit trailing private/`WLR_PRIVATE` fields
   entirely rather than guessing their shape: you only ever handle this
   type through a pointer wlroots itself allocated, so Zig never needs to
   know its true size. See `output_power.zig`.
4. **Check who else takes or returns this type before wiring it into
   `wlr.zig`.** Zig's `extern struct`s are nominally typed: a function
   still on `old` that takes `*old.Box` will not accept a `*wlr.Box` built
   from `c.zig`, even though the two are byte-for-byte identical. `Box`,
   `FBox`, and `Edges` hit this — they're drafted in `box.zig`/`edges.zig`
   and verified against the real headers, but `wlr.zig` still forwards
   them to `old` because `OutputLayout.getBox`, `XdgToplevel.setTiled`,
   and others haven't migrated yet. A type like that moves together with
   (or after) every not-yet-migrated signature that references it, not
   on its own. A protocol-generated header wlroots itself doesn't install
   (anything under `wlr_types_*_v1.h` that `#include`s its own
   `*-protocol.h`) needs that header generated at build time — see
   `output_power_protocol_header` in `build.zig` for the
   `wayland-scanner`-based pattern.
5. Build Debug and `-Doptimize=ReleaseSafe`, run `zig build test`, per the
   top-level AGENTS.md.
