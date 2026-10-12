<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Assets/wordmark-dark.svg">
    <img src="Assets/wordmark.svg" alt="SwiftSections" width="440">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/OlafAndreas/swift-sections/actions/workflows/ci.yml"><img src="https://github.com/OlafAndreas/swift-sections/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2F5F9E.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Swift-6.3%2B-1B8A8F.svg" alt="Swift 6.3+">
  <img src="https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20Linux-2F5F9E.svg" alt="macOS, iOS, Linux">
</p>

Read custom binary sections from every loaded image. The reading half of SE-0492.

```swift
import SwiftSections

#if canImport(Darwin)
let handlers = SectionName("__DATA_CONST,__swift5_hndlr")
#else
let handlers = SectionName("swift5_hndlr")
#endif

for buffer in SectionContents.loaded(handlers) {
    for record in buffer.bindMemory(to: HandlerRecord.self) { register(record) }
}

let token = SectionContents.observe(handlers) { buffer in
    // Called for each image already loaded, then for each image loaded later (Mach-O).
}
```

SE-0492 lets a `@section` `@used` global land in a named section. It leaves reading the
section back to each library. This package is that reading half, as a dependency-free
prototype of the runtime API proposed in
[swift-mediator/Pitches](https://github.com/OlafAndreas/swift-mediator/tree/main/Pitches).

## Install

```swift
.package(url: "https://github.com/OlafAndreas/swift-sections.git", from: "0.1.0")
```

Requires Swift 6.3 or later. No dependencies, no macros.

## How it works, and what only the runtime can fix

| | Images | Late images | Mechanism |
|---|---|---|---|
| Mach-O | all | observed | dyld add-image callback, then `getsectiondata`. The same registration the Swift runtime uses, so no racy `_dyld_image_count` walk. |
| ELF | all | on next call | `dl_iterate_phdr`, then each image's section headers are re-read from its file on disk, because ELF does not map them. The Swift 6.4 toolchain does not emit SE-0492's `swift5_sections` index, so there is nothing in memory to read. |
| COFF | none yet | | Port of Swift Testing's in-memory PE header walk. Contributions welcome. |

The ELF path works but is the clearest argument for doing this in the runtime: it opens and
parses every loaded image's file to recover addresses the linker knew. `swiftrt.o` could
record them once at link time, as it already does for Swift's own metadata sections.

## Rules for `observe` handlers

Handlers may run on the thread that loaded an image, under the loader's lock. Do not load
images, do not block on work that might, copy what you need and return. On ELF the handler
runs for the images loaded at the time of the call and is never called again.

## Who uses it

[swift-discovery](https://github.com/OlafAndreas/swift-discovery) builds keyed type discovery
on it, and [swift-mediator](https://github.com/OlafAndreas/swift-mediator) finds its handlers
through that.

## License

MIT. See [LICENSE](LICENSE).
