import Foundation
import LoopKit

class DanaKitUserSettingsViewModel: ObservableObject {
    @Published var storingUseroption = false
    @Published var lowReservoirRate: UInt8 = 0
    @Published var isTimeDisplay24H: Bool = true
    @Published var isButtonScrollOnOff: Bool = false
    @Published var beepAndAlarm: BeepAlarmType = .sound
    @Published var lcdOnTimeInSec: UInt8 = 0
    @Published var backlightOnTimeInSec: UInt8 = 0
    @Published var refillAmount: UInt16 = 0

    private let pumpManager: DanaKitPumpManager?

    init(_ pumpManager: DanaKitPumpManager?) {
        self.pumpManager = pumpManager

        if let pumpManager {
            lowReservoirRate = pumpManager.state.lowReservoirRate
            isTimeDisplay24H = pumpManager.state.isTimeDisplay24H
            isButtonScrollOnOff = pumpManager.state.isButtonScrollOnOff
            beepAndAlarm = pumpManager.state.beepAndAlarm
            lcdOnTimeInSec = pumpManager.state.lcdOnTimeInSec
            backlightOnTimeInSec = pumpManager.state.backlightOnTimInSec
            refillAmount = pumpManager.state.refillAmount
        }
    }

    func storeUserOption() {
        guard let pumpManager = self.pumpManager else {
            return
        }

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
            targetBg: pumpManager.state.targetBg
        )

        pumpManager.setUserSettings(data: model, completion: { _ in
            DispatchQueue.main.async {
                self.storingUseroption = false
            }
        })
    }
}
