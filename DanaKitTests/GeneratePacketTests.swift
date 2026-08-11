@testable import DanaKit
import Testing

@Suite struct GeneratePacketTests {
    @Test func generateBasalCancelTemporary() {
        let packet = generatePacketBasalCancelTemporary()

        #expect(packet.opCode == 98)
        #expect(packet.data == nil)
    }

    @Test func generateBasalGetProfileNumber() {
        let packet = generatePacketBasalGetProfileNumber()

        #expect(packet.opCode == 101)
        #expect(packet.data == nil)
    }

    @Test func generateBasalGetRate() {
        let packet = generatePacketBasalGetRate()

        #expect(packet.opCode == 103)
        #expect(packet.data == nil)
    }

    @Test func generateBasalSetProfileNumber() {
        let options = PacketBasalSetProfileNumber(profileNumber: 0)
        let packet = generatePacketBasalSetProfileNumber(options: options)

        #expect(packet.opCode == 100)
        #expect(packet.data == Data([0]))
    }

    @Test func generateBasalSetProfileRate() throws {
        let profileBasalRate: [Double] = Array(repeating: 0.5, count: 24)
        let options = PacketBasalSetProfileRate(profileNumber: 0, profileBasalRate: profileBasalRate)
        let packet = try generatePacketBasalSetProfileRate(options: options)

        let expectedData = Data([0] + Array(repeating: [50, 0], count: 24).flatMap { $0 })
        #expect(packet.opCode == 102)
        #expect(packet.data == expectedData)
    }

    @Test func generateBasalSetProfileRate_InvalidRateLength() {
        let profileBasalRate: [Double] = Array(repeating: 0.5, count: 23)
        let options = PacketBasalSetProfileRate(profileNumber: 0, profileBasalRate: profileBasalRate)

        #expect(throws: any Error.self) { try generatePacketBasalSetProfileRate(options: options) }
    }

    @Test func generateBasalSetSuspendOff() {
        let packet = generatePacketBasalSetSuspendOff()

        #expect(packet.opCode == 106)
        #expect(packet.data == nil)
    }

    @Test func generateBasalSetSuspendOn() {
        let packet = generatePacketBasalSetSuspendOn()

        #expect(packet.opCode == 105)
        #expect(packet.data == nil)
    }

    @Test func generateBasalSetTemporary() {
        let options = PacketBasalSetTemporary(temporaryBasalRatio: 200, temporaryBasalDuration: 1)
        let packet = generatePacketBasalSetTemporary(options: options)

        #expect(packet.opCode == 96)
        #expect(packet.data == Data([200, 1]))
    }

    @Test func generateBolusCancelExtended() {
        let packet = generatePacketBolusCancelExtended()

        #expect(packet.opCode == 73)
        #expect(packet.data == nil)
    }

    @Test func generateBolusGet24Circf() {
        let packet = generatePacketBolusGet24CIRCFArray()

        #expect(packet.opCode == 82)
        #expect(packet.data == nil)
    }

    @Test func generateBolusGetCalculationInformation() {
        let packet = generatePacketBolusGetCalculationInformation()

        #expect(packet.opCode == 75)
        #expect(packet.data == nil)
    }

    @Test func generateBolusGetCircf() {
        let packet = generatePacketBolusGetCIRCFArray()

        #expect(packet.opCode == 78)
        #expect(packet.data == nil)
    }

    @Test func generateBolusGetOption() {
        let packet = generatePacketBolusGetOption()

        #expect(packet.opCode == 80)
        #expect(packet.data == nil)
    }

    @Test func generateBolusGetStepOptionInformation() {
        let packet = generatePacketBolusGetStepInformation()

        #expect(packet.opCode == 64)
        #expect(packet.data == nil)
    }

    @Test func generateBolusSet24Circf_mmolPerL() throws {
        let options = PacketBolusSet24CIRCFArray(
            unit: 1,
            ic: Array(repeating: 0.5, count: 24),
            isf: Array(repeating: 1, count: 24)
        )
        let packet = try generatePacketBolusSet24CIRCFArray(options: options)

        let expectedData = Data(
            Array(repeating: [1, 0], count: 24).flatMap { $0 } + Array(repeating: [100, 0], count: 24).flatMap { $0 }
        )
        #expect(packet.opCode == 83)
        #expect(packet.data == expectedData)
    }

    @Test func generateBolusSet24Circf() throws {
        let options = PacketBolusSet24CIRCFArray(
            unit: 0,
            ic: Array(repeating: 0.5, count: 24),
            isf: Array(repeating: 1, count: 24)
        )
        let packet = try generatePacketBolusSet24CIRCFArray(options: options)

        let expectedData = Data(Array(repeating: [1, 0], count: 48).flatMap { $0 })
        #expect(packet.opCode == 83)
        #expect(packet.data == expectedData)
    }

    @Test func generateBolusSet24Circf_InvalidInput() {
        let optionsInvalidIc = PacketBolusSet24CIRCFArray(
            unit: 0,
            ic: Array(repeating: 0.5, count: 23),
            isf: Array(repeating: 1, count: 24)
        )
        let optionsInvalidIsf = PacketBolusSet24CIRCFArray(
            unit: 0,
            ic: Array(repeating: 0.5, count: 24),
            isf: Array(repeating: 1, count: 23)
        )

        #expect(throws: any Error.self) { try generatePacketBolusSet24CIRCFArray(options: optionsInvalidIc) }
        #expect(throws: any Error.self) { try generatePacketBolusSet24CIRCFArray(options: optionsInvalidIsf) }
    }

    @Test func generateBolusSetExtended() {
        let options = PacketBolusSetExtended(extendedAmount: 5, extendedDurationInHalfHours: 4)
        let packet = generatePacketBolusSetExtended(options: options)

        #expect(packet.opCode == 71)
        #expect(packet.data == Data([5, 0, 4]))
    }

    @Test func generateBolusSetOption() {
        let options = PacketBolusSetOption(
            extendedBolusOptionOnOff: 0,
            bolusCalculationOption: 1,
            missedBolusConfig: 1,
            missedBolus01StartHour: 0,
            missedBolus01StartMin: 0,
            missedBolus01EndHour: 0,
            missedBolus01EndMin: 0,
            missedBolus02StartHour: 0,
            missedBolus02StartMin: 0,
            missedBolus02EndHour: 0,
            missedBolus02EndMin: 0,
            missedBolus03StartHour: 0,
            missedBolus03StartMin: 0,
            missedBolus03EndHour: 0,
            missedBolus03EndMin: 0,
            missedBolus04StartHour: 0,
            missedBolus04StartMin: 0,
            missedBolus04EndHour: 0,
            missedBolus04EndMin: 0
        )
        let packet = generatePacketBolusSetOption(options: options)

        #expect(packet.opCode == 81)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
    }

    @Test func generateBolusStart_Speed12() {
        let options = PacketBolusStart(amount: 5, speed: .speed12)
        let packet = generatePacketBolusStart(options: options)

        #expect(packet.opCode == 74)
        #expect(packet.data == Data([244, 1, 0]))
    }

    @Test func generateBolusStart_Speed30() {
        let options = PacketBolusStart(amount: 5, speed: .speed30)
        let packet = generatePacketBolusStart(options: options)

        #expect(packet.opCode == 74)
        #expect(packet.data == Data([244, 1, 1]))
    }

    @Test func generateBolusStart_Speed60() {
        let options = PacketBolusStart(amount: 5, speed: .speed60)
        let packet = generatePacketBolusStart(options: options)

        #expect(packet.opCode == 74)
        #expect(packet.data == Data([244, 1, 2]))
    }

    @Test func generateBolusStop() {
        let packet = generatePacketBolusStop()

        #expect(packet.opCode == 68)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralAvgBolus() {
        let packet = generatePacketGeneralAvgBolus()

        #expect(packet.opCode == 16)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralClearUserTimeChangeFlag() {
        let packet = generatePacketGeneralClearUserTimeChangeFlag()

        #expect(packet.opCode == 35)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetDecRatio() {
        let packet = generatePacketGeneralGetPumpDecRatio()

        #expect(packet.opCode == 128)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetInitialScreenInformation() {
        let packet = generatePacketGeneralGetInitialScreenInformation()

        #expect(packet.opCode == 2)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetPumpCheck() {
        let packet = generatePacketGeneralGetPumpCheck()

        #expect(packet.opCode == 33)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetPumpTime() {
        let packet = generatePacketGeneralGetPumpTime()

        #expect(packet.opCode == 112)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetPumpTimeWithUtc() {
        let packet = generatePacketGeneralGetPumpTimeUtcWithTimezone()

        #expect(packet.opCode == 120)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetShippingInformation() {
        let packet = generatePacketGeneralGetShippingInformation()

        #expect(packet.opCode == 32)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetShippingVersion() {
        let packet = generatePacketGeneralGetShippingVersion()

        #expect(packet.opCode == 129)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetUserOption() {
        let packet = generatePacketGeneralGetUserOption()

        #expect(packet.opCode == 114)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralGetUserTimeChangeFlag() {
        let packet = generatePacketGeneralGetUserTimeChangeFlag()

        #expect(packet.opCode == 34)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralKeepConnection() {
        let packet = generatePacketGeneralKeepConnection()

        #expect(packet.opCode == 255)
        #expect(packet.data == nil)
    }

    @Test func generateGeneralSaveHistory() {
        let options = PacketGeneralSaveHistory(
            historyType: 1,
            historyDate: Date(timeIntervalSince1970: 1_701_774_000),
            historyCode: 1,
            historyValue: 1
        )
        let packet = generatePacketGeneralSaveHistory(options: options)

        #expect(packet.opCode == 224)
        #expect(packet.data == Data([1, 23, 12, 5, 11, 0, 0, 1, 1, 0]))
    }

    @Test func generateGeneralSetHistoryUploadMode_TurnOff() {
        let options = PacketGeneralSetHistoryUploadMode(mode: 0)
        let packet = generatePacketGeneralSetHistoryUploadMode(options: options)

        #expect(packet.opCode == 37)
        #expect(packet.data == Data([0]))
    }

    @Test func generateGeneralSetHistoryUploadMode_TurnOn() {
        let options = PacketGeneralSetHistoryUploadMode(mode: 1)
        let packet = generatePacketGeneralSetHistoryUploadMode(options: options)

        #expect(packet.opCode == 37)
        #expect(packet.data == Data([1]))
    }

    @Test func generateGeneralSetPumpTime() {
        // 2023-12-05T11:00:00.000 UTC
        let options = PacketGeneralSetPumpTime(time: Date(timeIntervalSince1970: 1_701_774_000))
        let packet = generatePacketGeneralSetPumpTime(options: options)

        #expect(packet.opCode == 113)
        #expect(packet.data == Data([23, 12, 5, 12, 0, 0]))
    }

    @Test func generateGeneralSetPumpTimeWithTimezone() {
        let options = PacketGeneralSetPumpTimeUtcWithTimezone(time: Date(timeIntervalSince1970: 1_701_774_000), zoneOffset: 1)
        let packet = generatePacketGeneralSetPumpTimeUtcWithTimezone(options: options)

        #expect(packet.opCode == 121)
        #expect(packet.data == Data([23, 12, 5, 11, 0, 0, 1]))
    }

    @Test func generateGeneralSetUserOption() {
        let options = PacketGeneralSetUserOption(
            isTimeDisplay24H: true,
            isButtonScrollOnOff: true,
            beepAndAlarm: 0,
            lcdOnTimeInSec: 10,
            backlightOnTimeInSec: 10,
            selectedLanguage: 1,
            units: 1,
            shutdownHour: 0,
            lowReservoirRate: 20,
            cannulaVolume: 250,
            refillAmount: 7,
            targetBg: 55
        )
        let packet = generatePacketGeneralSetUserOption(options: options)

        #expect(packet.opCode == 115)
        #expect(packet.data == Data([0, 1, 0, 10, 10, 1, 1, 0, 20, 250, 0, 7, 0, 55, 0]))
    }

    @Test func generateHistoryAlarmFromDate() {
        let options = PacketHistoryBase(from: Date(timeIntervalSince1970: 1_701_774_000), usingUtc: true)
        let packet = generatePacketHistoryAlarm(options: options)

        #expect(packet.opCode == 25)
        #expect(packet.data == Data([23, 12, 5, 11, 0, 0]))
    }

    @Test func generateHistoryAlarm() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryAlarm(options: options)

        #expect(packet.opCode == 25)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryAll() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryAll(options: options)

        #expect(packet.opCode == 31)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryBasal() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryBasal(options: options)

        #expect(packet.opCode == 26)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryBloodGlucose() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryBloodGlucose(options: options)

        #expect(packet.opCode == 21)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryBolus() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryBolus(options: options)

        #expect(packet.opCode == 17)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryCarbohydrates() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryCarbohydrates(options: options)

        #expect(packet.opCode == 22)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryDaily() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryDaily(options: options)

        #expect(packet.opCode == 18)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryPrime() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryPrime(options: options)

        #expect(packet.opCode == 19)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryRefill() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryRefill(options: options)

        #expect(packet.opCode == 20)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistorySuspend() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistorySuspend(options: options)

        #expect(packet.opCode == 24)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateHistoryTemporary() {
        let options = PacketHistoryBase(from: nil, usingUtc: true)
        let packet = generatePacketHistoryTemporary(options: options)

        #expect(packet.opCode == 23)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateLoopHistoryEventsFromDateInUTC() {
        let options = PacketLoopHistoryEvents(from: Date(timeIntervalSince1970: 1_701_774_000))
        let packet = generatePacketLoopHistoryEvents(options: options)

        #expect(packet.opCode == 194)
        #expect(packet.data == Data([23, 12, 5, 11, 0, 0]))
    }

    @Test func generateLoopHistoryEvents() {
        let options = PacketLoopHistoryEvents(from: nil)
        let packet = generatePacketLoopHistoryEvents(options: options)

        #expect(packet.opCode == 194)
        #expect(packet.data == Data([0, 1, 1, 0, 0, 0]))
    }

    @Test func generateLoopSetHistoryEvent() {
        let options = PacketLoopSetEventHistory(
            packetType: LoopHistoryEvents.carbs,
            time: Date(timeIntervalSince1970: 1_701_774_000),
            param1: 0,
            param2: 0
        )
        let packet = generatePacketLoopSetEventHistory(options: options)

        #expect(packet.opCode == 195)
        #expect(packet.data == Data([14, 23, 12, 5, 11, 0, 0, 0, 0, 0, 0]))
    }

    @Test func generateLoopSetTemporaryBasal() {
        let options = PacketLoopSetTemporaryBasal(percent: 200, duration: .min30)
        let packet = generatePacketLoopSetTemporaryBasal(options: options)

        #expect(packet.opCode == 193)
        #expect(packet.data == Data([200, 0, 160]))
    }

    @Test func generateLoopSetTemporaryBasalPercentGreaterThan500() {
        let options = PacketLoopSetTemporaryBasal(percent: 750, duration: .min15)
        let packet = generatePacketLoopSetTemporaryBasal(options: options)

        #expect(packet.opCode == 193)
        #expect(packet.data == Data([244, 1, 150]))
    }
}
