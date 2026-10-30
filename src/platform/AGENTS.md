# Platform module

The one place the OS shows: child handles (`child.zig`), directory watching
(`watch.zig`), the program's own path (`exe.zig`), and `child.h`/`self_exe.h`
for C and C++. Std only, no compositor imports. Linux today; the FreeBSD port
(`docs/plans/freebsd.md`) adds `freebsd_*.zig` parts without changing callers.

* **A `Handle` is not a pid.** Hold it for as long as you may signal; a bare
  `kill(pid)` is only safe while you have not reaped the child. `pid()` is
  null once reaped, but an unreaped zombie keeps its pid: check `exited()` too.
* **`Child` reaps, `Child.observe` does not.** Use `observe` when another owner
  (`session/services.zig`) collects the status; two reapers race.
* **Watch directories, not files**, so atomic replacement is seen. Adding a
  watched directory again returns the same `Watch` and queues nothing: add the
  new watches before removing the old. `isChange()` is "something happened or
  events were lost"; `lost()` means re-add the watch. Prefer `written` and
  `moved_to` over `modified` (often half-written).
* `drain` returning `error.Broken` means stop using the watcher. Callbacks may
  add watches, not call `drain`. Event names are valid only in the callback.
* Nothing here arms a timer or starts a thread; a caller retrying a failed
  `add` owns that clock.

Still direct Linux calls (later steps of the plan's phase P): `signalfd`/`epoll`
in the supervisor and DM daemon, `kill`/`wait4`, `/proc` walks, `SO_PEERCRED`.
