final class DanaKitDispatchGroup {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var count = 0

    func enter() {
        lock.lock()
        count += 1
        lock.unlock()
        group.enter()
    }

    func leave() {
        lock.lock()
        count -= 1
        guard count >= 0 else {
            // Prevent crash on multiple leave calls
            return
        }

        lock.unlock()
        group.leave()
    }
    
    @discardableResult
    func wait(timeout: DispatchTime) -> DispatchTimeoutResult {
        return group.wait(timeout: timeout)
    }
}
