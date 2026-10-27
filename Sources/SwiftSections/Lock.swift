#if canImport(Darwin)
import Darwin

/// A plain mutex for the Mach-O image registry. Not recursive: image-load callbacks may run
/// on the loader's thread, and nothing here must call back into the loader while holding it.
final class Lock: @unchecked Sendable {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>

    init() {
        mutex = .allocate(capacity: 1)
        pthread_mutex_init(mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deallocate()
    }

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        pthread_mutex_lock(mutex)
        defer { pthread_mutex_unlock(mutex) }
        return try body()
    }
}
#endif
