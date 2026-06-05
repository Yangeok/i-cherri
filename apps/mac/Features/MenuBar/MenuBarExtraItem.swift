import SwiftUI
import Inject
import Combine
import AppKit
import ICherriProtocol

// macOS menu bar status icon with quick-link popover showing receiver state.
public struct MenuBarExtraItem: Scene {
    @StateObject private var state = MenuBarState()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverContent(state: state)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            if #available(macOS 14.0, *) {
                Image(systemName: state.menuBarSymbolName)
                    .symbolEffect(.pulse, isActive: state.isReceiving)
            } else {
                Image(systemName: state.menuBarSymbolName)
            }
            if state.isReceiving {
                Text("\(Int(state.overallBackupProgress * 100))%")
                    .font(.caption2.monospacedDigit())
            }
        }
        .help(state.statusDescription)
    }
}

struct MenuBarPopoverContent: View {
    @ObserveInjection var inject
    @ObservedObject var state: MenuBarState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            statusSection
            Divider()
            actionsSection
        }
        .frame(width: 280)
        .padding(.vertical, 4)
        .enableInjection()
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: state.menuBarSymbolName)
                .font(.title2)
                .foregroundStyle(state.statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("iCherri Receiver")
                    .font(.headline)
                Text(state.statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(state.statusColor)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let headline = state.statusHeadline {
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if let deviceSummary = state.deviceSummary {
                statusRow(icon: "iphone", text: deviceSummary)
            }

            if let uploadSummary = state.uploadSummary {
                statusRow(icon: "arrow.up.circle", text: uploadSummary)
            }

            if let progressSummary = state.backupProgressSummary {
                statusRow(icon: "chart.bar.xaxis", text: progressSummary)
            }

            if let statusIssue = state.statusIssue {
                statusRow(icon: "exclamationmark.triangle", text: statusIssue)
            }

            statusRow(icon: "folder", text: state.backupFolderPath)

            if state.isReceiving {
                ProgressView(value: state.overallBackupProgress)
                    .tint(.accentColor)
                    .padding(.top, 2)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            MenuBarActionButton(title: "Open Dashboard", icon: "gauge") {
                state.openDashboard()
            }
            MenuBarActionButton(title: "Reveal Backup Folder", icon: "folder") {
                state.revealBackupFolder()
            }
            Divider()
            MenuBarActionButton(title: "Quit iCherri", icon: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func statusRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .frame(width: 12)
            Text(text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

struct MenuBarActionButton: View {
    let title: String
    let icon: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.0001)) // Hit-test area
    }
}

@MainActor
final class MenuBarState: ObservableObject {
    enum Status {
        case offline
        case ready
        case receiving
    }

    @Published var status: Status = .offline
    @Published var isReceiving = false
    @Published var overallBackupProgress: Double = 0
    @Published var connectedDeviceName: String?
    @Published var activeUploadCount = 0
    @Published var activeDeviceCount = 0
    @Published var backupFolderPath = AppCoordinator.shared.backupFolder.path
    @Published var isDashboardOpen = false
    @Published var backupProgressSummary: String?
    @Published var serverIssue: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        AppCoordinator.shared.$isServerRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSnapshot()
            }
            .store(in: &cancellables)

        AppCoordinator.shared.$backupFolder
            .receive(on: RunLoop.main)
            .sink { [weak self] folder in
                self?.backupFolderPath = folder.path
            }
            .store(in: &cancellables)

        AppCoordinator.shared.$serverIssue
            .receive(on: RunLoop.main)
            .sink { [weak self] issue in
                self?.serverIssue = Self.normalizedIssue(issue)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .receiverDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSnapshot()
            }
            .store(in: &cancellables)

        reloadSnapshot()
    }

    var statusDescription: String {
        switch status {
        case .offline:
            return serverIssue == nil ? "Receiver offline" : "Receiver failed to start"
        case .ready:
            return "Ready to receive"
        case .receiving:
            return "Receiving backup…"
        }
    }

    var statusColor: Color {
        switch status {
        case .offline:
            return .secondary
        case .ready, .receiving:
            return .green
        }
    }

    var menuBarSymbolName: String {
        switch status {
        case .offline, .ready:
            return "externaldrive.fill"
        case .receiving:
            return "externaldrive.fill.badge.icloud"
        }
    }

    var statusHeadline: String? {
        switch status {
        case .offline:
            return serverIssue == nil ? "Receiver is stopped" : "Startup failed"
        case .ready:
            return "Waiting for backup"
        case .receiving:
            return "Backup in progress"
        }
    }

    var statusIssue: String? {
        guard status == .offline else { return nil }
        return serverIssue
    }

    var deviceSummary: String? {
        if isReceiving {
            if activeDeviceCount > 1 {
                return "\(activeDeviceCount) devices connected"
            }
            return "Connected: \(connectedDeviceName ?? "iPhone")"
        }

        guard AppCoordinator.shared.isServerRunning else { return nil }
        return "Receiver on port \(AppCoordinator.shared.port)"
    }

    var uploadSummary: String? {
        guard isReceiving else { return nil }
        return activeUploadCount == 1 ? "1 active upload" : "\(activeUploadCount) active uploads"
    }

    func openDashboard() {
        NotificationCenter.default.post(name: .openDashboard, object: nil)
    }

    func revealBackupFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppCoordinator.shared.backupFolder])
    }

    private func reloadSnapshot() {
        backupFolderPath = AppCoordinator.shared.backupFolder.path
        serverIssue = Self.normalizedIssue(AppCoordinator.shared.serverIssue)

        Task {
            let sessions = (try? await DatabaseManager.shared.fetchAllSessions()) ?? []
            let devices = (try? await DatabaseManager.shared.fetchAllDevices()) ?? []
            let deviceNames = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0.deviceName) })
            let activeDeviceIDs = Array(Set(sessions.map(\.deviceId))).sorted()
            let totalExpected = sessions.reduce(Int64(0)) { $0 + max($1.expectedByteSize, 0) }
            let totalReceived = sessions.reduce(Int64(0)) { $0 + max($1.receivedBytes, 0) }
            let coveredBytesByDevice = (try? await DatabaseManager.shared.fetchCoveredBytesByDevice(deviceIDs: activeDeviceIDs)) ?? [:]
            let coverageSnapshot = await AppCoordinator.shared.backupRunProgressStore.snapshot(
                activeSessions: sessions,
                coveredBytesByDeviceID: coveredBytesByDevice
            )

            await MainActor.run {
                self.activeUploadCount = sessions.count
                self.activeDeviceCount = activeDeviceIDs.count
                self.connectedDeviceName = activeDeviceIDs.count == 1 ? deviceNames[activeDeviceIDs[0]] : nil
                self.isReceiving = !sessions.isEmpty

                if let snapshot = coverageSnapshot {
                    self.overallBackupProgress = snapshot.fractionCompleted
                    self.backupProgressSummary = "\(Self.formatBytes(snapshot.completedBytes)) / \(Self.formatBytes(snapshot.totalBytes)) backed up"
                } else {
                    let fallbackProgress = totalExpected > 0 ? min(max(Double(totalReceived) / Double(totalExpected), 0), 1) : 0
                    self.overallBackupProgress = fallbackProgress
                    self.backupProgressSummary = nil
                }

                if self.isReceiving {
                    self.status = .receiving
                } else if AppCoordinator.shared.isServerRunning {
                    self.status = .ready
                } else {
                    self.status = .offline
                }
            }
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    nonisolated static func normalizedIssue(_ issue: String?) -> String? {
        guard let issue else { return nil }
        let trimmed = issue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("iCherri.openDashboard")
    static let changeBackupFolder = Notification.Name("iCherri.changeBackupFolder")
    static let receiverDataDidChange = Notification.Name("iCherri.receiverDataDidChange")
}
