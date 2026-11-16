import Foundation
import LoopKit

class DanaKitUserSettingsViewModel: ObservableObject {
    @Published var storingUseroption: Bool
    @Published var lowReservoirRate: UInt8
    @Published var isTimeDisplay24H: Bool
    @Published var isButtonScrollOnOff: Bool
    @Published var beepAndAlarm: BeepAlarmType
    @Published var lcdOnTimeInSec: UInt8
    @Published var backlightOnTimeInSec: UInt8
    @Published var refillAmount: UInt16
    /// Only on Dana-i2. nil when the pump does not have this setting
    @Published var autoLock: Bool?

    private let pumpManager: DanaKitPumpManager

    init(_ pumpManager: DanaKitPumpManager) {
        self.pumpManager = pumpManager

        storingUseroption = false
        lowReservoirRate = pumpManager.state.lowReservoirRate
        isTimeDisplay24H = pumpManager.state.isTimeDisplay24H
        isButtonScrollOnOff = pumpManager.state.isButtonScrollOnOff
        beepAndAlarm = pumpManager.state.beepAndAlarm
        lcdOnTimeInSec = pumpManager.state.lcdOnTimeInSec
        backlightOnTimeInSec = pumpManager.state.backlightOnTimInSec
        refillAmount = pumpManager.state.refillAmount
        autoLock = pumpManager.state.autoLock
    }

    func storeUserOption() {
        storingUseroption = true
        let model = PacketGeneralSetUserOption(
            isTimeDisplay24H: isTimeDisplay24H,
            isButtonScrollOnOff: isButtonScrollOnOff,
            beepAndAlarm: beepAndAlarm.rawValue,
            lcdOnTimeInSec: lcdOnTimeInSec,
            backlightOnTimeInSec: backlightOnTimeInSec,
            selectedLanguage: pumpManager.state.selectedLanguage,
            units: pumpManager.state.units,
            shutdownHour: pumpManager.state.shutdownHour,
            lowReservoirRate: lowReservoirRate,
            cannulaVolume: pumpManager.state.cannulaVolume,
            refillAmount: refillAmount,
            targetBg: pumpManager.state.targetBg,
            autoLock: autoLock
        )

        pumpManager.setUserSettings(data: model, completion: { _ in
            DispatchQueue.main.async {
                self.storingUseroption = false
            }
        })
    }
}
