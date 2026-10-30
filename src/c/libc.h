/* The libc and Linux headers Zig code uses, translated once into the `c`
 * module (build/support.zig). Zig 0.17 has no @cImport.
 *
 * Translate libc declarations, not glibc's fortified inline wrappers: Zig
 * rejects their attribute(error) calls in ReleaseSafe. This affects the
 * translation only; Zig runtime safety and separately compiled C stay on. */
#undef _FORTIFY_SOURCE
#define _GNU_SOURCE 1

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fnmatch.h>
#include <grp.h>
#include <langinfo.h>
#include <linux/netlink.h>
#include <locale.h>
#include <monetary.h>
#include <poll.h>
#include <pthread.h>
#include <pwd.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>
