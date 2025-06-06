import CoreBluetooth

struct ConnectTaskController: PeripheralTaskController {

    typealias TaskSpec = ConnectTaskSpec

    private let task: SubjectTask

    init(_ task: SubjectTask) {
        self.task = task
    }

    func connect(centralManager: CBCentralManager, peripheral: CBPeripheral) -> SubjectTask {
        guard case .pending = task.state
        else {
            assert(false)
            return task
        }

        centralManager.connect(
    peripheral,
    options: [
        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
        CBConnectPeripheralOptionNotifyOnConnectionKey: true,
        CBConnectPeripheralOptionNotifyOnNotificationKey: true
    ]
)

        return task.with(state: task.state.processing(.connecting))
    }

    func handleConnectionChange(_ connectionChange: ConnectionChange) -> SubjectTask {
        guard case .processing(since: _, .connecting) = task.state
        else {
            assert(false)
            return task
        }

        return task.with(state: task.state.finished(connectionChange))
    }

    func cancel(centralManager: CBCentralManager, peripheral: CBPeripheral, error: Error?) -> SubjectTask {
        switch task.state {
        case .pending:
            return task.with(state: task.state.finished(.failedToConnect(error)))
        case .processing(since: _, .connecting):
            centralManager.cancelPeripheralConnection(peripheral)
            return task.with(state: task.state.finished(.failedToConnect(error)))
        case .finished:
            assert(false)
            return task
        }
    }
}
