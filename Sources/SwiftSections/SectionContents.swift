/// Reads custom sections from every loaded image.
///
/// This is a library-level prototype of the runtime API proposed as the follow-on to
/// SE-0492. The Swift runtime already tracks every loaded image for its own metadata
/// sections; this package rebuilds that tracking from outside, with the limits noted on
/// each platform.
public enum SectionContents {
    /// The contents of `section` in each currently loaded image that has it, one buffer per
    /// image, in image load order. Buffers remain valid while the image stays loaded.
    public static func loaded(_ section: SectionName) -> [UnsafeRawBufferPointer] {
        Platform.loaded(section)
    }

    /// Calls `handler` for each loaded image that has `section`, then for each image loaded
    /// afterwards while the token lives.
    ///
    /// Later images are only observed on Mach-O, where this package registers with dyld.
    /// On ELF and Windows there is no loader notification available to a library; the
    /// handler runs for the images loaded at the time of the call and never again.
    ///
    /// The handler may run on the thread that loaded an image, under the loader's lock. It
    /// must not load images or block on work that might, and should copy what it needs and
    /// return.
    public static func observe(
        _ section: SectionName,
        _ handler: @escaping @Sendable (UnsafeRawBufferPointer) -> Void
    ) -> ObservationToken {
        Platform.observe(section, handler)
    }
}

/// Keeps an observation alive. Dropping the token, or calling ``cancel()``, stops future calls.
public final class ObservationToken: Sendable {
    private let onCancel: @Sendable () -> Void

    init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() { onCancel() }

    deinit { onCancel() }
}
