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
   from `c.zig`, even though the two are byte-for-byte identical. Add a
   `comptime { assertSameLayout(NewType, old.OldType); }` next to the
   migrated type's declaration in `wlr.zig` (see `Box`/`FBox`/`Edges`),
   then `@ptrCast` (pointers) or `@bitCast` (value types passed by value,
   e.g. `Edges`) at each of the handful of call sites that still cross
   into an unmigrated function or signal — one line at each site, with a
   comment pointing back at the assert. That assert is what makes the
   cast provably safe, not a convention to trust blindly. This is almost
   always cheaper than waiting for every referencing type to migrate
   first: `Output`/`OutputLayout` crossed into `Backend` (the
   `new_output` signal — see `wlr.zig`'s `zig_wlroots` re-export and
   Server.zig/server/outputs.zig/startup_tasks.zig),
   `ForeignToplevelHandleV1`, `Cursor`, `OutputConfigurationV1`,
   `XdgSurface`/`XdgToplevel`, `LayerSurfaceV1`, `SessionLockSurfaceV1`,
   and a few test files' direct `Backend.headlessAddOutput` calls — each
   handled with one cast, not a bigger migration. Only wait when the
   type is a signal/event *payload* type itself and nothing else, or the
   crossing count looks larger than just migrating the other side too. A
   protocol-generated header wlroots itself doesn't install (anything
   under `wlr_types_*_v1.h` that `#include`s its own `*-protocol.h`)
   needs that header generated at build time — see
   `output_power_protocol_header` in `build.zig` for the
   `wayland-scanner`-based pattern.
5. Before trusting a signal's payload type, check who actually connects
   to it (`grep` for `.events.<name>.add(`) rather than assuming from the
   header comment. `wlr_output`'s `frame`/`description`/`destroy`
   signals carry the output itself as payload by convention, with no
   comment saying so and no dedicated event struct — only
   `damage`/`precommit`/`bind` (which nothing in RediWM connects to) were
   safe to leave as placeholder `wl.Signal(void)`.
6. Build Debug and `-Doptimize=ReleaseSafe`, run `zig build test`, per the
   top-level AGENTS.md. A pre-existing/environmental test failure doesn't
   excuse skipping this: compare against a `git worktree` of the commit
   before your change, per the top-level AGENTS.md, rather than assuming.
