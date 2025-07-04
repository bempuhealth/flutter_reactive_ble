import CoreBluetooth

enum ConnectionChange {
    case connected
    case failedToConnect(Error?)
    case disconnected(Error?)
}

final class CentralManagerDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let methodChannel: FlutterMethodChannel?

    typealias StateChangeHandler = (CBManagerState) -> Void
    typealias DiscoveryHandler = (CBPeripheral, AdvertisementData, RSSI) -> Void
    typealias ConnectionChangeHandler = (CBPeripheral, ConnectionChange) -> Void

    private let onStateChange: StateChangeHandler
    private let onDiscovery: DiscoveryHandler
    private let onConnectionChange: ConnectionChangeHandler

    init(
        methodChannel: FlutterMethodChannel?,
        onStateChange: @escaping StateChangeHandler,
        onDiscovery: @escaping DiscoveryHandler,
        onConnectionChange: @escaping ConnectionChangeHandler
    ) {
        self.methodChannel = methodChannel
        self.onStateChange = onStateChange
        self.onDiscovery = onDiscovery
        self.onConnectionChange = onConnectionChange
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onStateChange(central.state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        onDiscovery(peripheral, advertisementData, rssi.intValue)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onConnectionChange(peripheral, .connected)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onConnectionChange(peripheral, .failedToConnect(error))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        onConnectionChange(peripheral, .disconnected(error))
    }
    // 1 Jun 2024 - Ratul added this based on discussion with chat gpt and this post: https://github.com/PhilipsHue/flutter_reactive_ble/discussions/866
    // I am not sure currently what code should go in here though...
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("BLE restoration: willRestoreState called")

        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
                if peripheral.state == .disconnected {
                    central.connect(peripheral, options: [
                        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                        CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                        CBConnectPeripheralOptionNotifyOnNotificationKey: true
                    ])
                }
                // Rediscover services/characteristics if needed
                // You may need to call into your Central instance here, e.g.:
                // centralInstance.discoverServicesWithCharacteristics(for: peripheral, ...)
            }
        }

        if let services = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
            central.scanForPeripherals(withServices: services, options: nil)
        }

        // Optionally notify Dart via MethodChannel
        methodChannel?.invokeMethod("onBleRestored", arguments: nil)
    }
}
