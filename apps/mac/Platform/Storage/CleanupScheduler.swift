import Foundation

// Periodically purges expired upload sessions and their associated .tmp/incoming/ fragments.
actor CleanupScheduler {
    private let sessionManager: SessionManager
    private let incomingDir: URL
    private let interval: TimeInterval
    private var task: Task<Void, Never>?

    init(sessionManager: SessionManager, incomingDir: URL, interval: TimeInterval = 3600) {
        self.sessionManager = sessionManager
        self.incomingDir = incomingDir
        self.interval = interval
    }

    func start() {
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runCleanup()
                try? await Task.sleep(nanoseconds: UInt64((self?.interval ?? 3600) * 1_000_000_000))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    // MARK: - Cleanup Logic

    func runCleanup() async {
        do {
            let expired = try await sessionManager.fetchExpiredSessions()
            for session in expired {
                removeFile(at: session.tempPath)
                try? await sessionManager.failSession(uploadID: session.uploadID, error: "expired")
            }
            removeOrphanedTempFiles(knownPaths: Set(expired.map(\.tempPath)))
        } catch {
            // Log and continue; cleanup failure is non-fatal
        }
    }

    private func removeFile(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // Removes .tmp files in incomingDir that have no associated session record.
    private func removeOrphanedTempFiles(knownPaths: Set<String>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: incomingDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date().addingTimeInterval(-48 * 3600)
        for url in contents where url.pathExtension == "tmp" {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let created = attrs?[.creationDate] as? Date ?? Date()
            // Only delete orphaned files older than 48 h to avoid raciness
            if !knownPaths.contains(url.path), created < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
