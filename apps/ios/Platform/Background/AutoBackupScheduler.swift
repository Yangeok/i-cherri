import BackgroundTasks
import Foundation

@MainActor
final class AutoBackupScheduler {
    static let shared = AutoBackupScheduler()
    static let processingTaskIdentifier = "com.icherri.ios.auto-backup.processing"

    private var didRegisterBackgroundTasks = false
    private let engine: AutoBackupEngine

    init(engine: AutoBackupEngine = .shared) {
        self.engine = engine
    }

    func registerBackgroundTasks() {
        guard !didRegisterBackgroundTasks else { return }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self, let task = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handleProcessingTask(task)
        }

        didRegisterBackgroundTasks = true
    }

    func scheduleNextEvaluation() {
        let request = buildProcessingRequest()
        try? BGTaskScheduler.shared.submit(request)
    }

    func buildProcessingRequest() -> BGProcessingTaskRequest {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        return request
    }

    private func handleProcessingTask(_ task: BGProcessingTask) {
        scheduleNextEvaluation()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            let succeeded = await engine.handleProcessingTask(identifier: Self.processingTaskIdentifier)
            task.setTaskCompleted(success: succeeded)
        }
    }
}
