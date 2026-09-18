import CoreBluetooth
import Foundation
import LoopKit

class InteractiveBluetoothManager: NSObject, BluetoothManager {
    weak var pumpManager: DanaKitPumpManager?

    // The properties below are touched from the bluetooth queue, the main queue, the timeout task
    // and the thread issuing a command. Hence the locks
    @Locked var autoConnectUUID: String?
    @Locked var connectionCompletion: ((ConnectionResult) -> Void)?
    @Locked var connectionCallback: ((ConnectionResult) -> Void)?
    @Locked var devices: [DanaPumpScan] = []
    @Locked var isBusy: Bool = false

    @Locked var timoutCallback: Task<Void, Never>?

    let log = DanaLogger(category: "InteractiveBluetoothManager")
    var manager: CBCentralManager!
    let managerQueue = DispatchQueue(label: "com.DanaKit.bluetoothManagerQueue", qos: .unspecified)

    @Locked var peripheral: CBPeripheral?
    @Locked var peripheralManager: PeripheralManager?

    public var isConnected: Bool {
        self.manager.state == .poweredOn && self.peripheral?.state == .connected
    }

    override init() {
        super.init()

        managerQueue.sync {
            self.manager = CBCentralManager(delegate: self, queue: managerQueue)
        }
    }

    deinit {
        self.manager = nil
    }

    func ensureConnected(_ completion: @escaping (ConnectionResult) -> Void, _: String = #function) {
        let callback: (ConnectionResult) -> Void = { result in
            self.isBusy = true
            self._timoutCallback.mutate { task in
                task?.cancel()
                task = nil
            }

            if case .timeout = result {
                self.resetConnectionCompletion()
                self.connectionCallback = nil

            } else if case .success = result {
                self.resetConnectionCompletion()
                self.connectionCallback = nil

                do {
                    self.log.info("Sending keep alive message")
                    _ = try self.writeMessage(generatePacketGeneralKeepConnection())
                } catch {
                    self.log.error("Failed to send Keep alive message: \(error.localizedDescription)")
                }

                self.updateInitialState()
            }

            completion(result)
            self.isBusy = false
        }

        connectionCallback = callback

        // Device still has an active connection with pump and is probably busy with something
        if isConnected {
            if isBusy {
                log.error("Failed to connect: Already connected")
                pumpManager?.logDeviceCommunication("Dana - Failed to connect: Already connected", type: .connection)
                callback(.alreadyConnectedAndBusy)
                return
            }

            // We can re-use the current connection. YEAH!!
            callback(.success)

            // We stored the peripheral. We can quickly reconnect
        } else if let peripheral = peripheral {
            startTimeout(seconds: TimeInterval.seconds(15))

            connect(peripheral) { result in
                guard let connectionCallback = self.connectionCallback else {
                    // We've already hit the timeout function above
                    // Exit if we every hit this...
                    return
                }

                if case .success = result {
                    self.pumpManager?.logDeviceCommunication("Dana - Connected", type: .connection)
                    connectionCallback(result)

                } else if case let .failure(err) = result {
                    self.log.error("Failed to connect: " + err.localizedDescription)
                    self.pumpManager?.logDeviceCommunication(
                        "Dana - Failed to connect: " + err.localizedDescription,
                        type: .connection
                    )
                    connectionCallback(result)

                } else if case .requestedPincode = result {
                    self.log.error("Failed to connect: Requested pincode")
                    self.pumpManager?.logDeviceCommunication("Dana - Requested pincode", type: .connection)
                    connectionCallback(result)

                } else if case .invalidBle5Keys = result {
                    self.log.error("Failed to connect: Invalid ble 5 keys")
                    self.pumpManager?.logDeviceCommunication("Dana - Invalid ble 5 keys", type: .connection)
                    connectionCallback(result)
                }
            }
            // No active connection and no stored peripheral. We have to scan for device before being able to send command
        } else if pumpManager?.state.bleIdentifier != nil {
            do {
                startTimeout(seconds: TimeInterval.seconds(30))

                try connect(pumpManager!.state.bleIdentifier!) { result in
                    guard let connectionCallback = self.connectionCallback else {
                        // We've already hit the timeout function above
                        // Exit if we every hit this...
                        return
                    }

                    if case .success = result {
                        self.pumpManager?.logDeviceCommunication("Dana - Connected", type: .connection)
                        connectionCallback(result)

                    } else if case let .failure(err) = result {
                        self.log.error("Failed to connect: " + err.localizedDescription)
                        self.pumpManager?.logDeviceCommunication(
                            "Dana - Failed to connect: " + err.localizedDescription,
                            type: .connection
                        )
                        connectionCallback(result)

                    } else if case .requestedPincode = result {
                        self.log.error("Failed to connect: Requested pincode")
                        self.pumpManager?.logDeviceCommunication("Dana - Requested pincode", type: .connection)
                        connectionCallback(result)

                    } else if case .invalidBle5Keys = result {
                        self.log.error("Failed to connect: Invalid ble 5 keys")
                        self.pumpManager?.logDeviceCommunication("Dana - Invalid ble 5 keys", type: .connection)
                        connectionCallback(result)
                    }
                }
            } catch {
                log.error("Failed to connect: " + error.localizedDescription)
                pumpManager?.logDeviceCommunication("Dana - Failed to connect: " + error.localizedDescription, type: .connection)
                callback(.failure(error))
            }

        } else {
            // Should never reach, but is only possible if device is not onboard (we have no ble identifier to connect to)
            log.error("Pump is not onboarded")
            pumpManager?.logDeviceCommunication("Dana - Pump is not onboarded", type: .connection)
            callback(.failure(NSError(domain: "Pump is not onboarded", code: -1)))
        }
    }

    private func startTimeout(seconds: TimeInterval) {
        timoutCallback = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                // Take the callback, so it cannot be called by the connect completion as well
                let connectionCallback = self._connectionCallback.mutate { current -> ((ConnectionResult) -> Void)? in
                    defer { current = nil }
                    return current
                }
                guard let connectionCallback = connectionCallback else {
                    // This is amazing, we've done what we must and continue our live :)
                    return
                }

                pumpManager?.logDeviceCommunication("Dana - Failed to connect: Timeout reached...", type: .connection)
                self.log.error("Failed to connect: Timeout reached...")

                connectionCallback(.timeout)
            } catch {}
        }
    }

    func writeMessage(_ packet: DanaGeneratePacket) throws -> (any DanaParsePacketProtocol) {
        guard let peripheralManager = self.peripheralManager else {
            throw NSError(domain: "No connected device", code: 0, userInfo: nil)
        }

        return try peripheralManager.writeMessage(packet)
    }

    func disconnect(_ peripheral: CBPeripheral, force _: Bool) {
        autoConnectUUID = nil

        pumpManager?.logDeviceCommunication("Dana - Disconnected", type: .connection)
        manager.cancelPeripheralConnection(peripheral)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bleCentralManagerDidUpdateState(central)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        bleCentralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        bleCentralManager(central, didConnect: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isBusy = false
        bleCentralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        bleCentralManager(central, didFailToConnect: peripheral, error: error)
    }
}
