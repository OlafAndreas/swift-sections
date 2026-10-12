#if canImport(Darwin)
import MachO

/// Mach-O. Images are tracked through dyld's add-image callback, the same registration the
/// Swift runtime uses for its own sections. dyld invokes the callback synchronously for
/// every image already loaded when it is registered, then for each later image, so there
/// is no window in which an image is missed and no racy `_dyld_image_count` walk.
enum Platform {
    private struct Observer {
        let id: UInt64
        let section: SectionName
        let handler: @Sendable (UnsafeRawBufferPointer) -> Void
    }

    private final class Registry: @unchecked Sendable {
        let lock = Lock()
        var headers: [UnsafePointer<mach_header>] = []
        var observers: [Observer] = []
        var nextID: UInt64 = 0
    }

    private static let registry = Registry()

    /// Registering runs the callback for all current images before returning, which fills
    /// `registry.headers`. `registry` is a separate lazy static so that access from inside
    /// the callback does not re-enter this initializer.
    private static let registered: Bool = {
        _dyld_register_func_for_add_image { header, _ in
            guard let header else { return }
            let observers = registry.lock.withLock {
                registry.headers.append(header)
                return registry.observers
            }
            for observer in observers {
                if let bytes = contents(of: observer.section, in: header) { observer.handler(bytes) }
            }
        }
        return true
    }()

    static func loaded(_ section: SectionName) -> [UnsafeRawBufferPointer] {
        _ = registered
        let headers = registry.lock.withLock { registry.headers }
        return headers.compactMap { contents(of: section, in: $0) }
    }

    static func observe(
        _ section: SectionName,
        _ handler: @escaping @Sendable (UnsafeRawBufferPointer) -> Void
    ) -> ObservationToken {
        _ = registered
        // Snapshot and register under one lock: images in the snapshot are replayed here,
        // images added after it are delivered by the callback, and no image is both.
        let (id, snapshot) = registry.lock.withLock { () -> (UInt64, [UnsafePointer<mach_header>]) in
            let id = registry.nextID
            registry.nextID += 1
            registry.observers.append(Observer(id: id, section: section, handler: handler))
            return (id, registry.headers)
        }
        for header in snapshot {
            if let bytes = contents(of: section, in: header) { handler(bytes) }
        }
        return ObservationToken {
            registry.lock.withLock { registry.observers.removeAll { $0.id == id } }
        }
    }

    private static func contents(of section: SectionName, in header: UnsafePointer<mach_header>) -> UnsafeRawBufferPointer? {
        guard header.pointee.magic == MH_MAGIC_64 else { return nil }
        var size: UInt = 0
        let header64 = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        let data = section.segment.withUnsafeBufferPointer { segment in
            section.section.withUnsafeBufferPointer { name in
                getsectiondata(header64, segment.baseAddress!, name.baseAddress!, &size)
            }
        }
        guard let data, size > 0 else { return nil }
        return UnsafeRawBufferPointer(start: data, count: Int(size))
    }
}

#else
import SwiftSectionsShim

/// ELF. Section headers are not mapped at runtime, so each image's file is re-read to find
/// the section, through `dl_iterate_phdr` in the C shim. There is no loader notification a
/// library can register for, so `observe` only replays the images loaded at the call.
/// On other object formats the shim is a no-op and nothing is found.
enum Platform {
    private final class Collector {
        var buffers: [UnsafeRawBufferPointer] = []
    }

    static func loaded(_ section: SectionName) -> [UnsafeRawBufferPointer] {
        let collector = Collector()
        section.cName.withUnsafeBufferPointer { name in
            swiftsections_elf_enumerate(name.baseAddress!, { start, size, context in
                let collector = Unmanaged<Collector>.fromOpaque(context!).takeUnretainedValue()
                collector.buffers.append(UnsafeRawBufferPointer(start: start, count: size))
            }, Unmanaged.passUnretained(collector).toOpaque())
        }
        return collector.buffers
    }

    static func observe(
        _ section: SectionName,
        _ handler: @escaping @Sendable (UnsafeRawBufferPointer) -> Void
    ) -> ObservationToken {
        for bytes in loaded(section) { handler(bytes) }
        return ObservationToken {}
    }
}
#endif
