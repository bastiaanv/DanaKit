import Foundation
import LoopKit

class DanaKitDoseProgressReporter: DoseProgressReporter {
    var progress: DoseProgress {
        DoseProgress(deliveredUnits: deliveredUnits, percentComplete: deliveredUnits / total)
    }

    private let lock = UnfairLock()
    private var observers = WeakSet<DoseProgressObserver>()

    private let total: Double
    private var deliveredUnits: Double = 0

    public init(total: Double) {
        self.total = total
    }

    public func addObserver(_ observer: DoseProgressObserver) {
        observers.insert(observer)
    }

    public func removeObserver(_ observer: DoseProgressObserver) {
        observers.remove(observer)
    }

    public func notify(deliveredUnits: Double) {
        self.deliveredUnits = deliveredUnits
        let observersCopy = lock.withLock { observers }
        
        for observer in observersCopy {
            observer.doseProgressReporterDidUpdate(self)
        }
    }
}
