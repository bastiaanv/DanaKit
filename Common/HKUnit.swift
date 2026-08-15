import HealthKit

extension HKUnit {
    static let internationalUnitsPerHour: HKUnit = {
        HKUnit.internationalUnit().unitDivided(by: .hour())
    }()
}
