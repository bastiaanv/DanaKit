import Foundation

/// Guards a property which is touched from multiple threads (e.g. the bluetooth queue, the main queue and
/// the thread issuing a command).
/// Reading a reference (class instance, closure, String, etc.) while another thread replaces it is not
/// memory safe in Swift: the reader can end up retaining an object which has already been freed.
///
/// NOTE: Only a single get or set is atomic. Use `mutate` for anything that needs to read and write in one go
@propertyWrapper final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value

    init(wrappedValue: Value) {
        value = wrappedValue
    }

    var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            let oldValue = value
            value = newValue
            lock.unlock()

            // Release the previous value outside of the lock, since its deinit might run arbitrary code
            withExtendedLifetime(oldValue) {}
        }
    }

    func mutate<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        let oldValue = value
        defer {
            lock.unlock()
            withExtendedLifetime(oldValue) {}
        }

        return body(&value)
    }
}
