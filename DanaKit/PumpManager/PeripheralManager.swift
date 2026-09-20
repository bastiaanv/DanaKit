import CoreBluetooth
import SwiftUI

class PeripheralManager: NSObject {
    private let log = DanaLogger(category: "PeripheralManager")

    private let connectedDevice: CBPeripheral
    private let bluetoothManager: BluetoothManager
    /// Read on the bluetooth queue and cleared on the main queue
    @Locked private var completion: ((ConnectionResult) -> Void)?

    private var pumpManager: DanaKitPumpManager
    private let encryptor = DanaKitEncryption()

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

    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    private var pendingPacket: DanaKitBasePacket?
    private var writeQueue: DanaKitDispatchGroup?
    private var writeResponse: (any DanaParsePacketProtocol)?

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

        encryptor.setEnhancedEncryption(pumpManager.state.encryptionMode)
        peripheral.delegate = self
    }

    deinit {
        if let semaphore = self.writeQueue {
            semaphore.leave()
        }
    }

    func writeMessage(_ packet: DanaKitBasePacket) throws -> (any DanaParsePacketProtocol) {
        let command = (UInt16(DanaPacketType.TYPE_RESPONSE) << 8) + UInt16(packet.opCode)
        let packetData = try packet.generate()

        let writeQ = DanaKitDispatchGroup()
        writeQ.enter()

        try claim(packet, with: writeQ)

        // Make sure we have the correct state
        if packet.opCode == DanaPacketType.OPCODE_REVIEW__SET_HISTORY_UPLOAD_MODE, !packetData.isEmpty {
            pumpManager.state.isInFetchHistoryMode = packetData[0] == 0x01
        } else {
            pumpManager.state.isInFetchHistoryMode = false
        }

        var data = encryptor.encodePacket(operationCode: packet.opCode, buffer: packetData, deviceName: deviceName)
        log.debug("Sending data - Name: \(packet.name), OpCode: \(packet.opCode), Encoded data: \(data.hexString())", type: .send)

        if encryptor.shouldDoSecondLevel() {
            data = encryptor.encodeSecondLevel(data: data)
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
    private func claim(_ packet: DanaKitBasePacket, with writeQ: DanaKitDispatchGroup) throws {
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
        pendingPacket = packet
    }

    /// Deregisters the awaited command and returns its response, if one has been received in time
    private func release() -> (any DanaParsePacketProtocol)? {
        stateLock.lock()
        defer { stateLock.unlock() }

        writeQueue = nil
        pendingPacket = nil

        let response = writeResponse
        writeResponse = nil

        return response
    }

    /// The command a response is currently awaited for, if any
    private var awaitedPacket: DanaKitBasePacket? {
        stateLock.lock()
        defer { stateLock.unlock() }

        return writeQueue == nil ? nil : pendingPacket
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

        let service = peripheral.services?.first(where: { $0.uuid == CBUUID.DANAKIT_SERVICE })
        if service == nil {
            log.error("Failed to discover dana data service...")
            connectionFailure(NSError(domain: "Failed to discover dana data service...", code: 0, userInfo: nil))
            return
        }

        log.debug("Discovered service \(CBUUID.DANAKIT_SERVICE)")
        peripheral.discoverCharacteristics([CBUUID.DANAKIT_READ_CHAR, CBUUID.DANAKIT_WRITE_CHAR], for: service!)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            log.error("\(error!.localizedDescription)")
            connectionFailure(error!)
            return
        }

        let service = peripheral.services!.first(where: { $0.uuid == CBUUID.DANAKIT_SERVICE })!
        readCharacteristic = service.characteristics?.first(where: { $0.uuid == CBUUID.DANAKIT_READ_CHAR })
        writeCharacteristic = service.characteristics?.first(where: { $0.uuid == CBUUID.DANAKIT_WRITE_CHAR })

        guard writeCharacteristic != nil, let readCharacteristic = readCharacteristic else {
            log.error("Failed to discover dana write or read characteristic")
            connectionFailure(NSError(domain: "Failed to discover dana write or read characteristic", code: 0, userInfo: nil))
            return
        }

        log.debug("Discovered characteristics \(CBUUID.DANAKIT_READ_CHAR) and \(CBUUID.DANAKIT_WRITE_CHAR)")
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

        let data = encryptor.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__PUMP_CHECK,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending Initial encryption request. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendTimeInfo() {
        let data = encryptor.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending normal time information. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendV3PairingInformation(_ requestNewPairing: UInt8) {
        let data = encryptor.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION,
            buffer: Data([requestNewPairing]),
            deviceName: deviceName
        )

        log.debug("Sending RSv3 time information. Data: \(data.hexString())")
        writeValue(data)
    }

    // 0x00 Start encryption, 0x01 Request pairing
    private func sendV3PairingInformationEmpty() {
        var (pairingKey, randomPairingKey) = encryptor.getPairingKeys()
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

        encryptor.setPairingKeys(pairingKey: pairingKey, randomPairingKey: randomPairingKey, randomSyncKey: randomSyncKey)
        sendV3PairingInformation(0)
    }

    private func sendPairingRequest() {
        let data = encryptor.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_REQUEST,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending pairing request. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendEasyMenuCheck() {
        let data = encryptor.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__GET_EASYMENU_CHECK,
            buffer: nil,
            deviceName: deviceName
        )

        log.debug("Sending easy menu check. Data: \(data.hexString())")
        writeValue(data)
    }

    private func sendBLE5PairingInformation() {
        let data = encryptor.encodePacket(
            operationCode: DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION,
            buffer: Data([0, 0, 0, 0]),
            deviceName: deviceName
        )

        log.debug("Sending BLE5 time information. Data: \(Data([0, 0, 0, 0]).hexString())")
        writeValue(data)
    }

    private func sendPassKeyCheck(_ pairingKey: Data) {
        let data = encryptor.encodePacket(
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

        encryptor.setPairingKeys(pairingKey: pairingKey, randomPairingKey: randomPairingKey, randomSyncKey: nil)
        pumpManager.state.pairingKey = pairingKey
        pumpManager.state.randomPairingKey = randomPairingKey

        sendV3PairingInformation(0)
    }

    private func processEasyMenuCheck(_: Data) {
        if encryptor.isDanaRS() {
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
        encryptor.setPairingKeys(pairingKey: pairingKey, randomPairingKey: Data(), randomSyncKey: nil)
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
            encryptor.setEnhancedEncryption(EncryptionType.DEFAULT.rawValue)
            encryptionModeSet = true

            pumpManager.state.ignorePassword = false

            let (pairingKey, _) = encryptor.getPairingKeys()
            if !pairingKey.isEmpty {
                sendPassKeyCheck(pairingKey)
            } else {
                sendPairingRequest()
            }
        } else if data.count == 9, isOk(data) {
            // response OK v3, 2nd layer encryption
            log.info("Setting encryption mode to RSv3")
            encryptor.setEnhancedEncryption(EncryptionType.RSv3.rawValue)
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
            encryptor.setEnhancedEncryption(EncryptionType.BLE_5.rawValue)
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

                // Always report the connection result on the main queue, never on the bluetooth queue
                DispatchQueue.main.async {
                    completion(.invalidBle5Keys)
                }
                return
            }

            encryptor.setBle5Key(ble5Key: ble5Keys)
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
        if encryptor.isDanaI() {
            finishConnection()

        } else if encryptor.isDanaRS() {
            // data[2] : 0x00 OK  0x01 Error, No pairing
            if data[2] == 0x00 {
                let (pairingKey, randomPairingKey) = encryptor.getPairingKeys()
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

        DispatchQueue.main.async {
            completion(.requestedPincode(errorMessage))
        }
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
        if !data.isEmpty, pumpManager.state.isConnected, encryptor.shouldDoSecondLevel() {
            log.debug("Second lvl decryption", type: .receive)
            data = encryptor.decodeSecondLevel(data: data)
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

        log.debug("Received message! Starting to decrypt data: \(rawMessage.hexString())", type: .receive)
        let decryptedData = encryptor.decodePacket(buffer: rawMessage, deviceName: deviceName)

        guard !decryptedData.isEmpty else {
            log.error("Decryption failed...")
            return
        }

        log.debug("Decoding successful! Data: \(decryptedData.hexString())", type: .receive)
        if decryptedData[0] == DanaPacketType.TYPE_ENCRYPTION_RESPONSE {
            processConnectHandshake(decryptedData)
            return
        }

        if decryptedData[0] == DanaPacketType.TYPE_NOTIFY {
            processNotify(decryptedData)
            return
        }

        if decryptedData[0] == DanaPacketType.TYPE_RESPONSE {
            processMessage(decryptedData)
            return
        }

        log.error("Received invalid packet type \(decryptedData[0])", type: .receive)
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
                        "Received invalid packets. Starting bytes do not exists in message. Encryption mode possibly wrong Data: \(readBuffer.hexString())",
                        type: .receive
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
            readBuffer[length + 5] == PACKET_END_BYTE || readBuffer[length + 5] == ENCRYPTED_END_BYTE,
            readBuffer[length + 6] == PACKET_END_BYTE || readBuffer[length + 6] == ENCRYPTED_END_BYTE
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
        guard let awaitedPacket, data[OpCodeIndex] == awaitedPacket.opCode else {
            log.error("No stream found to send this message back...")
            return
        }

        let message = awaitedPacket.parse(data: data, usingUtc: pumpManager.state.usingUtc)

        do {
            let json = String(bytes: try JSONEncoder().encode(message), encoding: .utf8) ?? "EMPTY"
            log.info(
                "Received data - Operation code: \(message.opCode ?? 0), JSON packet: \(json)",
                type: .receive
            )
        } catch {}

        stateLock.lock()
        defer { stateLock.unlock() }

        guard let semaphore = writeQueue else {
            log.warning("Command \(awaitedPacket.opCode) is not awaiting a response anymore. Dropping it...", type: .receive)
            return
        }

        if let historyItem = message.data as? HistoryItem {
            guard historyItem.code == HistoryCode.RECORD_TYPE_DONE_UPLOAD else {
                historyLog.append(historyItem)
                return
            }

            writeResponse = DanaParsePacket<[HistoryItem]>(
                success: true,
                rawData: Data([]),
                data: historyLog.map({ $0 })
            )

            historyLog = []
            semaphore.leave()
            return
        }

        writeResponse = message
        semaphore.leave()
    }

    private func processNotify(_ data: Data) {
        switch data[OpCodeIndex] {
        case DanaPacketType.OPCODE_NOTIFY__DELIVERY_COMPLETE:
            let message = DanaNotifyDeliveryComplete().parse(data: data, usingUtc: pumpManager.state.usingUtc)
            if let data = message.data as? PacketNotifyDeliveryComplete {
                pumpManager.notifyBolusDone(deliveredUnits: data.deliveredInsulin)
            }
            return
        case DanaPacketType.OPCODE_NOTIFY__DELIVERY_RATE_DISPLAY:
            let message = DanaNotifyDeliveryRateDisplay().parse(data: data, usingUtc: pumpManager.state.usingUtc)
            if let data = message.data as? PacketNotifyDeliveryRateDisplay {
                pumpManager.notifyBolusDidUpdate(deliveredUnits: data.deliveredInsulin)
            }
            return
        case DanaPacketType.OPCODE_NOTIFY__ALARM:
            let message = DanaNotifyAlarm().parse(data: data, usingUtc: pumpManager.state.usingUtc)
            if let data = message.data as? PacketNotifyAlarm {
                pumpManager.notifyBolusError()
                pumpManager.notifyAlert(data.alert)
            }
            return
        default:
            return
        }
    }

    private func processConnectHandshake(_ data: Data) {
        guard !isConnectionFinished else {
            let message = "Ignoring encryption packet received after connection was established. Data: \(data.hexString())"
            log.warning(message, type: .receive)
            return
        }

        switch data[1] {
        case DanaPacketType.OPCODE_ENCRYPTION__PUMP_CHECK:
            processConnectResponse(data)
            return
        case DanaPacketType.OPCODE_ENCRYPTION__TIME_INFORMATION:
            processEncryptionResponse(data)
            return
        case DanaPacketType.OPCODE_ENCRYPTION__CHECK_PASSKEY:
            if data[2] == 0x05 {
                sendTimeInfo()
            } else {
                sendPairingRequest()
            }
            return
        case DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_REQUEST:
            processPairingRequest(data)
            return
        case DanaPacketType.OPCODE_ENCRYPTION__PASSKEY_RETURN:
            processPairingRequest2(data)
            return
        case DanaPacketType.OPCODE_ENCRYPTION__GET_PUMP_CHECK:
            if data[2] == 0x05 {
                sendTimeInfo()
            } else {
                sendEasyMenuCheck()
            }
            return
        case DanaPacketType.OPCODE_ENCRYPTION__GET_EASYMENU_CHECK:
            processEasyMenuCheck(data)
            return
        default:
            log.error("Received invalid encryption command type \(data[1])", type: .receive)
            return
        }
    }

    private func isHistoryPacket(opCode: UInt16) -> Bool {
        opCode > DanaPacketType.OPCODE_REVIEW__BOLUS && opCode < DanaPacketType.OPCODE_REVIEW__ALL_HISTORY
    }
}
