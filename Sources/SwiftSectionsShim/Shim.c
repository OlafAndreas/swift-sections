#include "SwiftSectionsShim.h"

#if defined(__ELF__)
#define _GNU_SOURCE
#include <elf.h>
#include <fcntl.h>
#include <link.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if __SIZEOF_POINTER__ == 8
typedef Elf64_Ehdr Ehdr; typedef Elf64_Shdr Shdr;
#else
typedef Elf32_Ehdr Ehdr; typedef Elf32_Shdr Shdr;
#endif

struct request {
    const char *section;
    swiftsections_callback callback;
    void *context;
};

static int read_at(int fd, void *buffer, size_t size, off_t offset) {
    size_t done = 0;
    while (done < size) {
        ssize_t n = pread(fd, (char *)buffer + done, size - done, offset + (off_t)done);
        if (n <= 0) return 0;
        done += (size_t)n;
    }
    return 1;
}

// ELF section headers are not part of any PT_LOAD segment, so they are not in memory.
// Re-read them from the image's file and translate the section's link-time address with
// the image's load bias. This is what the Swift runtime would avoid by recording section
// bounds at link time.
static int visit(struct dl_phdr_info *info, size_t size, void *data) {
    struct request *request = data;
    const char *path = info->dlpi_name;
    if (path == NULL || path[0] == '\0') path = "/proc/self/exe";   // the main executable
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return 0;                                             // e.g. the vDSO

    Ehdr header;
    if (!read_at(fd, &header, sizeof header, 0) || memcmp(header.e_ident, ELFMAG, SELFMAG) != 0
        || header.e_shentsize != sizeof(Shdr) || header.e_shnum == 0 || header.e_shstrndx >= header.e_shnum) {
        close(fd); return 0;
    }
    size_t table_size = (size_t)header.e_shnum * sizeof(Shdr);
    Shdr *sections = malloc(table_size);
    if (sections == NULL || !read_at(fd, sections, table_size, (off_t)header.e_shoff)) {
        free(sections); close(fd); return 0;
    }
    Shdr *names = &sections[header.e_shstrndx];
    char *name_table = malloc(names->sh_size);
    if (name_table == NULL || !read_at(fd, name_table, names->sh_size, (off_t)names->sh_offset)) {
        free(name_table); free(sections); close(fd); return 0;
    }
    for (unsigned i = 0; i < header.e_shnum; i++) {
        Shdr *s = &sections[i];
        if (s->sh_type == SHT_NOBITS || s->sh_name >= names->sh_size) continue;
        if (strcmp(name_table + s->sh_name, request->section) != 0) continue;
        if ((s->sh_flags & SHF_ALLOC) == 0) continue;
        const void *start = (const void *)(info->dlpi_addr + s->sh_addr);
        request->callback(start, (size_t)s->sh_size, request->context);
        break;
    }
    free(name_table); free(sections); close(fd);
    return 0;
}

void swiftsections_elf_enumerate(const char *section, swiftsections_callback callback, void *context) {
    struct request request = { section, callback, context };
    dl_iterate_phdr(visit, &request);
}
#else
void swiftsections_elf_enumerate(const char *section, swiftsections_callback callback, void *context) {
    (void)section; (void)callback; (void)context;
}
#endif
