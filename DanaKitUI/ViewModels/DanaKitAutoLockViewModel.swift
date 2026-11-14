import Foundation
import LoopKit

class DanaKitAutoLockViewModel: ObservableObject {
    @Published var autoLock: Bool
    @Published var storingAutoLock = false
    @Published var failedAutoLock = false

    private let pumpManager: DanaKitPumpManager
    private let nextStep: () -> Void

    init(_ pumpManager: DanaKitPumpManager, nextStep: @escaping () -> Void) {
        self.pumpManager = pumpManager
        self.nextStep = nextStep

        autoLock = pumpManager.state.autoLock ?? false
    }

    func storeAutoLock() {
        // The user options have just been read from the pump while pairing, nothing to change
        guard autoLock != pumpManager.state.autoLock else {
            nextStep()
            return
        }

        storingAutoLock = true
        failedAutoLock = false
        let model = PacketGeneralSetUserOption(
            isTimeDisplay24H: pumpManager.state.isTimeDisplay24H,
            isButtonScrollOnOff: pumpManager.state.isButtonScrollOnOff,
            beepAndAlarm: pumpManager.state.beepAndAlarm.rawValue,
            lcdOnTimeInSec: pumpManager.state.lcdOnTimeInSec,
            backlightOnTimeInSec: pumpManager.state.backlightOnTimInSec,
            selectedLanguage: pumpManager.state.selectedLanguage,
            units: pumpManager.state.units,
            shutdownHour: pumpManager.state.shutdownHour,
            lowReservoirRate: pumpManager.state.lowReservoirRate,
            cannulaVolume: pumpManager.state.cannulaVolume,
            refillAmount: pumpManager.state.refillAmount,
            targetBg: pumpManager.state.targetBg,
            autoLock: autoLock
        )

        pumpManager.setUserSettings(data: model) { success in
            DispatchQueue.main.async {
                self.storingAutoLock = false

                guard success else {
                    self.failedAutoLock = true
                    return
                }

                self.pumpManager.state.autoLock = self.autoLock
                self.pumpManager.notifyStateDidChange()
                self.nextStep()
            }
        }
    }
}
