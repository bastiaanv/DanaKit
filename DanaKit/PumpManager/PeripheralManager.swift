import CoreBluetooth
import os.log
import SwiftUI

class PeripheralManager: NSObject {
    private let log = DanaLogger(category: "PeripheralManager")

    private let connectedDevice: CBPeripheral
    private let bluetoothManager: BluetoothManager
    private var completion: ((ConnectionResult) -> Void)?

    private var pumpManager: DanaKitPumpManager

    /// Guards `readBuffer`, `readBufferUpdatedAt`, `writeQueue`, `pendingCommand` and `writeResponse`.
    /// Those are touched from both the thread issuing the command and the bluetooth queue
    private let stateLock = NSLock()
    private var readBuffer = Data([])
    private var readBufferUpdatedAt: Date?

    private let okCharCodes: [UInt8] = [0x4F, 0x4B] // O, K
    private let pumpCharCodes: [UInt8] = [0x50, 0x55, 0x4D, 0x50] // P, U, M, P
    private let busyCharCodes: [UInt8] = [0x42, 0x55, 0x53, 0x59] // B, U, S, Y

    private let PACKET_START_BYTE: UInt8 = 0xA5
    private let PACKET_END_BYTE: UInt8 = 0x5A
    private let ENCRYPTED_START_BYTE: UInt8 = 0xAA
    private let ENCRYPTED_END_BYTE: UInt8 = 0xEE

    public static let SERVICE_UUID = CBUUID(string: "FFF0")
    private let READ_CHAR_UUID = CBUUID(string: "FFF1")
    private var readCharacteristic: CBCharacteristic?
    private let WRITE_CHAR_UUID = CBUUID(string: "FFF2")
    private var writeCharacteristic: CBCharacteristic?

    private var writeQueue: DanaKitDispatchGroup?
    private var writeResponse: (any DanaParsePacketProtocol)?

    /// The command we are currently awaiting a response for. The pump echos the command of the
    /// request in its response, which allows us to recognize the response of a command which has
    /// already timed out. Handing such a response to the next command would return a packet of a
    /// completely different type than the caller expects
    private var pendingCommand: UInt16?

    // Handshake state. Scoped to this connection, since a PeripheralManager is created per connection
    private var pumpCheckSent = false
    private var encryptionModeSet = false
    private var isConnectionFinished = false

    private var historyLog: [HistoryItem] = []

    private var deviceName: String {
        pumpManager.state.deviceName ?? ""
    }

    public init(
        _ peripheral: CBPeripheral,
        _ bluetoothManager: BluetoothManager,
        _ pumpManager: DanaKitPumpManager,
        _ completion: @escaping (ConnectionResult) -> Void
    ) {
        connectedDevice = peripheral
        self.bluetoothManager = bluetoothManager
        self.pumpManager = pumpManager
        self.completion = completion

        super.init()

        peripheral.delegate = self
    }

    deinit {
        if let semaphore = self.writeQueue {
            semaphore.leave()
        }
    }

    func writeMessage(_ packet: DanaGeneratePacket) throws -> (any DanaParsePacketProtocol) {
        let command = (UInt16(packet.type ?? DanaPacketType.TYPE_RESPONSE) << 8) + UInt16(packet.opCode)

        let writeQ = DanaKitDispatchGroup()
        writeQ.enter()

        try claim(command, with: writeQ)

        pumpManager.logDeviceCommunication(
            "Sending data - Name: \(packet.name), Operation code: \(packet.opCode), data: \(packet.data?.hexString() ?? "nil")",
            type: .send
        )

        // Make sure we have the correct state
        if packet.opCode == CommandGeneralSetHistoryUploadMode, let data = packet.data {
            pumpManager.state.isInFetchHistoryMode = data[0] == 0x01
        } else {
            pumpManager.state.isInFetchHistoryMode = false
        }

        var data = DanaKitEncryption.encodePacket(operationCode: packet.opCode, buffer: packet.data, deviceName: deviceName)
        log.debug("Sending opCode: \(packet.opCode), encrypted data: \(data.hexString())")

        if DanaKitEncryption.enhancedEncryption != EncryptionType.DEFAULT.rawValue {
            data = DanaKitEncryption.encodeSecondLevel(data: data)
            log.debug("Second level encrypted data: \(data.hexString())")
        }

        let isHistoryPacket = self.isHistoryPacket(opCode: command)
        let timeout = !isHistoryPacket ? TimeInterval.seconds(4) : TimeInterval.seconds(21)

        while !data.isEmpty {
            let end = min(20, data.count)
            let message = data.subdata(in: 0 ..< end)

            writeValue(message)
            data = data.subdata(in: end ..< data.count)
        }

        // Wait for response or timeout timer...
        _ = writeQ.wait(timeout: .now() + timeout)

        guard let response = release() else {
            throw NSError(domain: "Timeout has been hit...", code: 0, userInfo: nil)
        }

        return response
    }

    /// Registers this command as the one we are awaiting a response for
    private func claim(_ command: UInt16, with writeQ: DanaKitDispatchGroup) throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard writeQueue == nil else {
            throw NSError(domain: "A command is already running", code: 0, userInfo: nil)
        }

        // Get rid of the leftovers of a command which has timed out. Without this, a half received
        // message would block the read buffer for the remainder of this connection, since every
        // following message would be appended to it, and the items of an aborted history upload
        // would be reported a second time
        discardStaleReadBuffer()
        writeResponse = nil
        historyLog = []

        writeQueue = writeQ
        pendingCommand = command
    }

    /// Deregisters the awaited command and returns its response, if one has been received in time
    private func release() -> (any DanaParsePacketProtocol)? {
        stateLock.lock()
        defer { stateLock.unlock() }

        writeQueue = nil
        pendingCommand = nil

        let response = writeResponse
        writeResponse = nil

        return response
    }

    /// The command a response is currently awaited for, if any
    private var awaitedCommand: UInt16? {
        stateLock.lock()
        defer { stateLock.unlock() }

        return writeQueue == nil ? nil : pendingCommand
    }

    private enum DeliveryResult {
        /// The response has been handed over. The group has to be left
        case delivered(DanaKitDispatchGroup)
        /// A history item has been collected. The upload is still running
        case collected
        /// Nobody is awaiting this response (anymore)
        case dropped
    }

    /// Hands the response over to the command which is awaiting it. History items are collected
    /// until the pump signals the end of the upload
    private func deliver(_ message: any DanaParsePacketProtocol) -> DeliveryResult {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard let semaphore = writeQueue, pendingCommand == message.command else {
            return .dropped
        }

        if let historyItem = message.data as? HistoryItem {
            guard historyItem.code == HistoryCode.RECORD_TYPE_DONE_UPLOAD else {
                historyLog.append(historyItem)
                return .collected
            }

            writeResponse = DanaParsePacket<[HistoryItem]>(
                success: true,
                rawData: Data([]),
                data: historyLog.map({ $0 })
            )

            historyLog = []
            return .delivered(semaphore)
        }

        writeResponse = message
        return .delivered(semaphore)
    }

    /// Drops a partially received message which nobody is waiting for anymore.
    /// Must be called while holding `stateLock`
    private func discardStaleReadBuffer() {
        guard !readBuffer.isEmpty else {
            return
        }

        // The chunks of a single message arrive within milliseconds of each other. Anything older
        // belongs to a command which has been given up on
        if let updatedAt = readBufferUpdatedAt, Date.now.timeIntervalSince(updatedAt) < .seconds(2) {
            return
        }

        log.warning("Discarding \(readBuffer.count) bytes of a message which was never completed")
        readBuffer = Data([])
        readBufferUpdatedAt = nil
    }

    private func connectionFailure(_ error: any Error) {
        bluetoothManager.manager.cancelPeripheralConnection(connectedDevice)

        guard let completion = self.completion else {
            return
        }

        DispatchQueue.main.async {
            completion(.failure(error))
        }
    }
}

extension PeripheralManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            log.error("\(error!.localizedDescription)")
            connectionFailure(error!)
            return
        }

        let service = peripheral.services?.first(where: { $0.uuid == PeripheralManager.SERVICE_UUID })
        if service == nil {
            log.error("Failed to discover dana data service...")
            connectionFailure(NSError(domain: "Failed to discover dana data service...", code: 0, userInfo: nil))
            return
        }

        log.debug("Discovered service \(PeripheralManager.SERVICE_UUID)")
        peripheral.discoverCharacteristics([READ_CHAR_UUID, WRITE_CHAR_UUID], for: service!)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            log.error("\(error!.localizedDescription)")
            connectionFailure(error!)
            return
        }

        let service = peripheral.services!.first(where: { $0.uuid == PeripheralManager.SERVICE_UUID })!
        readCharacteristic = service.characteristics?.first(where: { $0.uuid == READ_CHAR_UUID })
        writeCharacteristic = service.characteristics?.first(where: { $0.uuid == WRITE_CHAR_UUID })

        guard writeCharacteristic != nil, let readCharacteristic = readCharacteristic else {
            log.error("Failed to discover dana write or read characteristic")
            connectionFailure(NSError(domain: "Failed to discover dana write or read characteristic", code: 0, userInfo: nil))
            return
        }

        log.debug("Discovered characteristics \(READ_CHAR_UUID) and \(WRITE_CHAR_UUID)")
        peripheral.setNotifyValue(true, for: readCharacteristic)
    }

    func peripheral(_: CBPeripheral, didUpdateNotificationStateFor _: CBCharacteristic, error: Error?) {
        guard error == nil else {
            log.error("\(error!.localizedDescription)")
            connectionFailure(error!)
            return
        }

        log.debug("Notifications has been enabled. Sending starting handshake")
        sendFirstMessageEncryption()
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            log.error("\(error!.localizedDescription)")
            connectionFailure(error!)
            return
        }

        guard let data = characteristic.value else {
            return
        }

        log.debug("Receiving data: \(data.hexString())")
        parseReceivedValue(data)
    }

    private func writeValue(_ data: Data) {
        guard let writeCharacteristic = writeCharacteristic else {
            log.error("No write characteristic available. Device might be disconnected...")
            return
        }

        log.debug("Writing data \(data.hexString())")
        connectedDevice.writeValue(data, for: writeCharacteristic, type: .withoutResponse)
    }
}

// MARK: - Encryption/Connection functions

extension PeripheralManager {
    private func sendFirstMessageEncryption() {
        guard !pumpCheckSent else {
            log.warning("PUMP_CHECK has already been sent for this connection. Ignoring duplicate call")
            return
        }

        pumpCheckSent = true

        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__PUMP_CHECK,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending Initial encryption request. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendTimeInfo() {
        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending normal time information. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendV3PairingInformation(_ requestNewPairing: UInt8) {
        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION,
            buffer: Data([requestNewPairing]),
            deviceName: deviceName
        )

        log.debug("Sending RSv3 time information. Data: \(data.hexString())")
        writeValue(data)
    }

    // 0x00 Start encryption, 0x01 Request pairing
    private func sendV3PairingInformationEmpty() {
        var (pairingKey, randomPairingKey) = DanaKitEncryption.getPairingKeys()
        if pairingKey.filter({ $0 != 0 }).isEmpty || randomPairingKey.filter({ $0 != 0 }).isEmpty {
            pairingKey = pumpManager.state.pairingKey
            randomPairingKey = pumpManager.state.randomPairingKey

            if pairingKey.filter({ $0 != 0 }).isEmpty || randomPairingKey.filter({ $0 != 0 }).isEmpty {
                sendV3PairingInformation(1)
                return
            }
        }

        let randomSyncKey = pumpManager.state.randomSyncKey
        let message =
            "Setting encryption keys. Pairing key: \(pairingKey.hexString()), random pairing key: \(randomPairingKey.hexString()), random sync key: \(randomSyncKey)"
        log.debug(message)

        DanaKitEncryption.setPairingKeys(pairingKey: pairingKey, randomPairingKey: randomPairingKey, randomSyncKey: randomSyncKey)
        sendV3PairingInformation(0)
    }

    private func sendPairingRequest() {
        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_REQUEST,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending pairing request. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendEasyMenuCheck() {
        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__GET_EASYMENU_CHECK,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending easy menu check. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendBLE5PairingInformation() {
        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION,
            buffer: Data([0, 0, 0, 0]),
            deviceName: deviceName
        )

        log.debug("Sending BLE5 time information. Data: \(Data([0, 0, 0, 0]).hexString())")
        writeValue(data)
    }

    private func sendPassKeyCheck(_ pairingKey: Data) {
        let data = DanaKitEncryption.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__CHECK_PASSKEY,
            buffer: pairingKey,
            deviceName: deviceName
        )

        log.debug("Sending Passkey check. Data: \(data.hexString())")
        writeValue(data)
    }

    /// Used after entering PIN codes (only for DanaRS v3)
    public func finishV3Pairing(_ pairingKey: Data, _ randomPairingKey: Data) {
        log
            .debug(
                "Storing security keys: Pairing key: \(pairingKey.hexString()), random pairing key: \(randomPairingKey.hexString())"
            )

        DanaKitEncryption.setPairingKeys(pairingKey: pairingKey, randomPairingKey: randomPairingKey, randomSyncKey: nil)
        pumpManager.state.pairingKey = pairingKey
        pumpManager.state.randomPairingKey = randomPairingKey

        sendV3PairingInformation(0)
    }

    private func processEasyMenuCheck(_: Data) {
        if DanaKitEncryption.enhancedEncryption == EncryptionType.RSv3.rawValue {
            sendV3PairingInformationEmpty()
        } else {
            sendTimeInfo()
        }
    }

    private func processPairingRequest(_ data: Data) {
        if data[2] == 0x00 {
            // Everything is order. Waiting for pump to send OPCODE_ENCRYPTION__PASSKEY_RETURN
            return
        }

        log.error("Passkey request failed. Data: \(data.hexString())")
        connectionFailure(NSError(domain: "Passkey request failed", code: 0, userInfo: nil))
    }

    private func processPairingRequest2(_ data: Data) {
        sendTimeInfo()

        log.info("processPairingRequest2 -> pairingKey: \(data.subdata(in: 2 ..< 4).hexString())")
        let pairingKey = data.subdata(in: 2 ..< 4)
        DanaKitEncryption.setPairingKeys(pairingKey: pairingKey, randomPairingKey: Data(), randomSyncKey: nil)
    }

    private func processConnectResponse(_ data: Data) {
        guard !encryptionModeSet else {
            // The pump can answer PUMP_CHECK a second time (often with an empty payload) after the handshake moved on.
            // Failing the connection here would tear down a session which is doing just fine
            log.warning("Ignoring duplicate PUMP_CHECK response. Data: \(data.hexString())")
            return
        }

        if data.count == 4, isOk(data) {
            // response OK v1
            log.info("Setting encryption mode to DEFAULT")
            DanaKitEncryption.setEnhancedEncryption(EncryptionType.DEFAULT.rawValue)
            encryptionModeSet = true

            pumpManager.state.ignorePassword = false

            let (pairingKey, _) = DanaKitEncryption.getPairingKeys()
            if !pairingKey.isEmpty {
                sendPassKeyCheck(pairingKey)
            } else {
                sendPairingRequest()
            }
        } else if data.count == 9, isOk(data) {
            // response OK v3, 2nd layer encryption
            log.info("Setting encryption mode to RSv3")
            DanaKitEncryption.setEnhancedEncryption(EncryptionType.RSv3.rawValue)
            encryptionModeSet = true

            pumpManager.state.ignorePassword = true

            pumpManager.state.hwModel = data[5]
            pumpManager.state.pumpProtocol = data[7]

            // Grab syncKey
            pumpManager.state.randomSyncKey = data[data.count - 1]

            if pumpManager.state.hwModel == 0x05 {
                sendV3PairingInformationEmpty()
            } else if pumpManager.state.hwModel == 0x06 {
                sendEasyMenuCheck()
            } else {
                log.error("Got invalid hwModel \(pumpManager.state.hwModel)")
                connectionFailure(NSError(domain: "Invalid hwModel", code: 0, userInfo: nil))
            }
        } else if data.count == 14, isOk(data) {
            log.info("Setting encryption mode to BLE5")
            DanaKitEncryption.setEnhancedEncryption(EncryptionType.BLE_5.rawValue)
            encryptionModeSet = true

            pumpManager.state.hwModel = data[5]
            pumpManager.state.pumpProtocol = data[7]

            guard pumpManager.state.hwModel == 0x09 || pumpManager.state.hwModel == 0x0A else {
                log.error("Got invalid hwModel \(pumpManager.state.hwModel)")
                connectionFailure(NSError(domain: "Invalid hwModel", code: 0, userInfo: nil))
                return
            }

            var ble5Keys = data.subdata(in: 8 ..< 14)
            if !ble5Keys.filter({ $0 == 0 }).isEmpty {
                // Try to get keys from previous session
                ble5Keys = pumpManager.state.ble5Keys
            }

            guard ble5Keys.filter({ $0 == 0 }).isEmpty else {
                log.error("Invalid BLE-5 keys. Please unbound device and try again.")

                bluetoothManager.manager.cancelPeripheralConnection(connectedDevice)
                guard let completion = self.completion else {
                    return
                }

                completion(.invalidBle5Keys)
                return
            }

            DanaKitEncryption.setBle5Key(ble5Key: ble5Keys)
            pumpManager.state.ble5Keys = ble5Keys
            sendBLE5PairingInformation()
        } else if data.count == 6, isPump(data) {
            log.error("PUMP_CHECK error. Data: \(data.hexString())")
            connectionFailure(NSError(domain: "PUMP_CHECK error", code: 0, userInfo: nil))
        } else if data.count == 6, isBusy(data) {
            log.error("PUMP_CHECK_BUSY error. Data: \(data.hexString())")
            connectionFailure(NSError(domain: "PUMP_CHECK_BUSY error", code: 0, userInfo: nil))
        } else {
            log.error("PUMP_CHECK error, wrong serial number. Data: \(data.hexString())")
            connectionFailure(NSError(domain: "PUMP_CHECK error, wrong serial number", code: 0, userInfo: nil))
        }
    }

    private func processEncryptionResponse(_ data: Data) {
        if DanaKitEncryption.enhancedEncryption == EncryptionType.BLE_5.rawValue {
            finishConnection()

        } else if DanaKitEncryption.enhancedEncryption == EncryptionType.RSv3.rawValue {
            // data[2] : 0x00 OK  0x01 Error, No pairing
            if data[2] == 0x00 {
                let (pairingKey, randomPairingKey) = DanaKitEncryption.getPairingKeys()
                if pairingKey.isEmpty || randomPairingKey.isEmpty {
                    log.debug("Device is requesting pincode")
                    promptPincode(nil)
                    return
                }

                finishConnection()
            } else {
                sendV3PairingInformation(1)
            }
        } else {
            let highByte = UInt16((data[data.count - 1] & 0xFF) << 8)
            let lowByte = UInt16(data[data.count - 2] & 0xFF)
            let password = (highByte + lowByte) ^ 0x0D87
            if password != pumpManager.state.devicePassword, !pumpManager.state.ignorePassword {
                log.error("Invalid password")
                connectionFailure(NSError(domain: "Invalid password", code: 0, userInfo: nil))
                return
            }

            finishConnection()
        }
    }

    private func finishConnection() {
        isConnectionFinished = true
        pumpManager.state.isConnected = true
        log.info("Connection and encryption successful!")

        guard let completion = self.completion else {
            log.error("No completion available...")
            return
        }

        DispatchQueue.main.async {
            completion(.success)
            self.completion = nil
        }
    }

    private func promptPincode(_ errorMessage: String?) {
        guard let completion = self.completion else {
            log.error("No completion callback...")
            return
        }

        completion(.requestedPincode(errorMessage))
    }

    private func isOk(_ data: Data) -> Bool {
        data[2] == okCharCodes[0] && data[3] == okCharCodes[1]
    }

    private func isPump(_ data: Data) -> Bool {
        data[2] == pumpCharCodes[0] && data[3] == pumpCharCodes[1] && data[4] == pumpCharCodes[2] && data[5] == pumpCharCodes[3]
    }

    private func isBusy(_ data: Data) -> Bool {
        data[2] == busyCharCodes[0] && data[3] == busyCharCodes[1] && data[4] == busyCharCodes[2] && data[5] == busyCharCodes[3]
    }
}

// MARK: Parsers for incomming messages

extension PeripheralManager {
    private func parseReceivedValue(_ receievedData: Data) {
        var data = receievedData
        if !data.isEmpty && pumpManager.state.isConnected && DanaKitEncryption.enhancedEncryption != EncryptionType.DEFAULT
            .rawValue
        {
            log.debug("Second lvl decryption")
            data = DanaKitEncryption.decodeSecondLevel(data: data)
        }

        let rawMessage: Data
        switch appendToReadBuffer(data) {
        case .incomplete:
            return
        case .unrecoverable:
            bluetoothManager.manager.cancelPeripheralConnection(connectedDevice)
            return
        case let .message(message):
            rawMessage = message
        }

        log.debug("Received message! Starting to decrypt data: \(rawMessage.hexString())")
        let decryptedData = DanaKitEncryption.decodePacket(buffer: rawMessage, deviceName: deviceName)

        guard !decryptedData.isEmpty else {
            log.error("Decryption failed...")
            return
        }

        log.debug("Decoding successful! Data: \(decryptedData.hexString())")
        if decryptedData[0] == DanaPacketType.TYPE_ENCRYPTION_RESPONSE {
            guard !isConnectionFinished else {
                // The handshake is done. A late encryption packet must never be able to fail the connection
                log.warning("Ignoring encryption packet received after connection was established. Data: \(decryptedData.hexString())")
                return
            }

            switch decryptedData[1] {
            case DanaPacketType.OPCODE_ENCRYPTION__PUMP_CHECK:
                processConnectResponse(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION:
                processEncryptionResponse(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__CHECK_PASSKEY:
                if decryptedData[2] == 0x05 {
                    sendTimeInfo()
                } else {
                    sendPairingRequest()
                }
                return
            case DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_REQUEST:
                processPairingRequest(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_RETURN:
                processPairingRequest2(decryptedData)
                return
            case DanaPacketType.OPCODE_ENCRYPTION__GET_PUMP_CHECK:
                if decryptedData[2] == 0x05 {
                    sendTimeInfo()
                } else {
                    sendEasyMenuCheck()
                }
                return
            case DanaPacketType.OPCODE_ENCRYPTION__GET_EASYMENU_CHECK:
                processEasyMenuCheck(decryptedData)
                return
            default:
                log.error("Received invalid encryption command type \(decryptedData[1])")
                return
            }
        }

        guard decryptedData[0] == DanaPacketType.TYPE_RESPONSE || decryptedData[0] == DanaPacketType.TYPE_NOTIFY else {
            log.error("Received invalid packet type \(decryptedData[0])")
            return
        }

        processMessage(decryptedData)
    }

    private enum ReadBufferResult {
        /// The message is still being assembled
        case incomplete
        /// A complete raw message, ready to be decrypted
        case message(Data)
        /// The received data cannot be interpreted at all. The connection should be dropped
        case unrecoverable
    }

    /// Adds the received chunk to the read buffer and hands back the raw message once it is complete
    private func appendToReadBuffer(_ data: Data) -> ReadBufferResult {
        stateLock.lock()
        defer { stateLock.unlock() }

        readBuffer.append(data)
        readBufferUpdatedAt = Date.now

        guard readBuffer.count >= 6 else {
            // Buffer is not ready to be processed
            return .incomplete
        }

        if
            !(readBuffer[0] == PACKET_START_BYTE || readBuffer[0] == ENCRYPTED_START_BYTE) ||
            !(readBuffer[1] == PACKET_START_BYTE || readBuffer[1] == ENCRYPTED_START_BYTE)
        {
            // The buffer does not start with the opening bytes. Check if the buffer is filled with old data
            if let indexStartByte = readBuffer.firstIndex(of: PACKET_START_BYTE) {
                readBuffer = readBuffer.subdata(in: indexStartByte ..< readBuffer.count)
            } else if let indexEncryptedStartByte = readBuffer.firstIndex(of: ENCRYPTED_START_BYTE) {
                readBuffer = readBuffer.subdata(in: indexEncryptedStartByte ..< readBuffer.count)
            } else {
                log
                    .error(
                        "Received invalid packets. Starting bytes do not exists in message. Encryption mode possibly wrong Data: \(readBuffer.hexString())"
                    )
                clearReadBuffer()
                return .unrecoverable
            }
        }

        let length = Int(readBuffer[2])
        guard length + 7 == readBuffer.count else {
            guard readBuffer.count < length + 7 else {
                // The buffer can never complete anymore. Get rid of it, otherwise every following
                // message would be appended to it and this connection would never receive anything again
                log
                    .error(
                        "Read buffer got out of sync. Should be: \(length + 7), currently: \(readBuffer.count). Data: \(readBuffer.hexString())"
                    )
                clearReadBuffer()
                return .incomplete
            }

            // Not all packets have been received yet...
            log.debug("Not all packets have been received yet - Should be: \(length + 7), currently: \(readBuffer.count)")
            return .incomplete
        }

        guard
            (readBuffer[length + 5] == PACKET_END_BYTE || readBuffer[length + 5] == ENCRYPTED_END_BYTE) &&
            (readBuffer[length + 6] == PACKET_END_BYTE || readBuffer[length + 6] == ENCRYPTED_END_BYTE)
        else {
            // Invalid packets received...
            log.error("Received invalid packets. Ending bytes do not match. Data: \(readBuffer.hexString())")
            clearReadBuffer()
            return .incomplete
        }

        let rawMessage = readBuffer
        clearReadBuffer()

        return .message(rawMessage)
    }

    /// Must be called while holding `stateLock`
    private func clearReadBuffer() {
        readBuffer = Data([])
        readBufferUpdatedAt = nil
    }

    private func processMessage(_ data: Data) {
        let message = parseMessage(data: data, usingUtc: pumpManager.state.usingUtc)
        guard let message = message else {
            log.error("Received unparsable message. Data: \(data.hexString())")
            return
        }

        do {
            let json = String(bytes: try JSONEncoder().encode(message), encoding: .utf8) ?? "EMPTY"
            pumpManager.logDeviceCommunication(
                "Received data - Operation code: \(message.opCode ?? 0), JSON packet: \(json)",
                type: .receive
            )
        } catch {}

        if let notifyType = message.notifyType {
            switch notifyType {
            case CommandNotifyDeliveryComplete:
                if let data = message.data as? PacketNotifyDeliveryComplete {
                    pumpManager.notifyBolusDone(deliveredUnits: data.deliveredInsulin)
                    return
                }
            case CommandNotifyDeliveryRateDisplay:
                if let data = message.data as? PacketNotifyDeliveryRateDisplay {
                    pumpManager.notifyBolusDidUpdate(deliveredUnits: data.deliveredInsulin)
                    return
                }
            case CommandNotifyAlarm:
                if let data = message.data as? PacketNotifyAlarm {
                    pumpManager.notifyBolusError()
                    pumpManager.notifyAlert(data.alert)
                    return
                }
            default:
                break
            }

            pumpManager.notifyBolusError()
            return
        }

        // Message received and dequeueing timeout
        guard let awaitedCommand = awaitedCommand else {
            log.error("No stream found to send this message back...")
            return
        }

        // A response which arrives after its command has timed out must never be handed to the
        // command which is running now: that one is expecting a completely different packet
        guard message.command == awaitedCommand else {
            log
                .warning(
                    "Ignoring response of command \(message.command ?? 0) while awaiting command \(awaitedCommand). It is most likely the late response of a command which has timed out"
                )
            return
        }

        switch deliver(message) {
        case let .delivered(semaphore):
            semaphore.leave()
        case .collected:
            break
        case .dropped:
            log.warning("Command \(awaitedCommand) is not awaiting a response anymore. Dropping it...")
        }
    }

    private func isHistoryPacket(opCode: UInt16) -> Bool {
        opCode > CommandHistoryBolus && opCode < CommandHistoryAll
    }
}
