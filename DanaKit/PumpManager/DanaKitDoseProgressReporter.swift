import Foundation
import LoopKit

final class DanaKitDoseProgressState {
    var progress: DoseProgress {
        lock.withLock {
            DoseProgress(deliveredUnits: deliveredUnits, percentComplete: deliveredUnits / total)
        }
    }

    private let lock = UnfairLock()
    private var reporters = WeakSet<DanaKitDoseProgressReporter>()

    private let total: Double
    private var deliveredUnits: Double = 0

    init(total: Double) {
        self.total = total
    }

    func reporting(on queue: DispatchQueue) -> DoseProgressReporter {
        DanaKitDoseProgressReporter(source: self, reportingQueue: queue)
    }

    fileprivate func addReporter(_ reporter: DanaKitDoseProgressReporter) {
        lock.withLock { reporters.insert(reporter) }
    }

    fileprivate func removeReporter(_ reporter: DanaKitDoseProgressReporter) {
        lock.withLock { reporters.remove(reporter) }
    }

    func notify(deliveredUnits: Double) {
        let reportersCopy = lock.withLock {
            self.deliveredUnits = deliveredUnits
            return reporters
        }

        for reporter in reportersCopy {
            reporter.notify()
        }
    }
}

final class DanaKitDoseProgressReporter: DoseProgressReporter {
    private let source: DanaKitDoseProgressState
    private let reportingQueue: DispatchQueue
    private let observers = WeakSynchronizedSet<DoseProgressObserver>()

    var progress: DoseProgress {
        source.progress
    }

    init(source: DanaKitDoseProgressState, reportingQueue: DispatchQueue) {
        self.source = source
        self.reportingQueue = reportingQueue
        source.addReporter(self)
    }

    deinit {
        source.removeReporter(self)
    }

    func addObserver(_ observer: DoseProgressObserver) {
        observers.insert(observer, queue: reportingQueue)
    }

    func removeObserver(_ observer: DoseProgressObserver) {
        observers.removeElement(observer)
    }

    fileprivate func notify() {
        observers.forEach { observer in
            observer.doseProgressReporterDidUpdate(self)
        }
    }
}
