#ifndef SWIFT_SECTIONS_SHIM_H
#define SWIFT_SECTIONS_SHIM_H

#include <stddef.h>

typedef void (*swiftsections_callback)(const void *start, size_t size, void *context);

/// ELF only. Calls `callback` once for every loaded image that contains a section named
/// `section`, with the section's in-memory bounds. No-op on other object formats.
void swiftsections_elf_enumerate(const char *section, swiftsections_callback callback, void *context);

#endif
