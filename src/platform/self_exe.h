/* The running program's own path, for the C and C++ code that cannot import
 * platform/exe.zig. Linux reads /proc/self/exe. */
#ifndef REDIWM_SELF_EXE_H
#define REDIWM_SELF_EXE_H

#include <stddef.h>
#include <sys/types.h>
#include <unistd.h>

/* Writes the NUL-terminated absolute path of the running executable into
 * `buf`. Returns its length, or -1 when it cannot be read or does not fit. */
static inline ssize_t rediwm_self_exe(char *buf, size_t size) {
    if (size < 2) return -1;
    ssize_t len = readlink("/proc/self/exe", buf, size - 1);
    if (len <= 0) return -1;
    buf[len] = '\0';
    return len;
}

#endif
