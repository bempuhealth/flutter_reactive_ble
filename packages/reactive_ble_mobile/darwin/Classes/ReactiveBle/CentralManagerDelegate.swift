import CoreBluetooth

enum ConnectionChange {
    case connected
    case failedToConnect(Error?)
    case disconnected(Error?)
}

final class CentralManagerDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    typealias StateChangeHandler = (CBManagerState) -> Void
    typealias DiscoveryHandler = (CBPeripheral, AdvertisementData, RSSI) -> Void
    typealias ConnectionChangeHandler = (CBPeripheral, ConnectionChange) -> Void

    private let onStateChange: StateChangeHandler
    private let onDiscovery: DiscoveryHandler
    private let onConnectionChange: ConnectionChangeHandler

    init(
        onStateChange: @escaping StateChangeHandler,
        onDiscovery: @escaping DiscoveryHandler,
        onConnectionChange: @escaping ConnectionChangeHandler
    ) {
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

        // 1. Get restored peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
                // Optionally, reconnect or resubscribe if needed
                // central.connect(peripheral, options: nil)
            }
        }

        // 2. Restore subscriptions to characteristics (if needed)
        if let services = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID] {
            central.scanForPeripherals(withServices: services, options: nil)
        }

        // 3. Optionally, notify Dart side via MethodChannel
        // To notify Dart, you need to pass a reference to a FlutterMethodChannel or registrar into this class.
        // Example:
        // methodChannel?.invokeMethod("onBleRestored", arguments: nil)
    }
}
