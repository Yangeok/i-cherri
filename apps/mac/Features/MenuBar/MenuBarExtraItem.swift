import SwiftUI
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
                Image(systemName: state.isReceiving ? "externaldrive.fill.badge.icloud" : "externaldrive.fill")
                    .symbolEffect(.pulse, isActive: state.isReceiving)
            } else {
                Image(systemName: state.isReceiving ? "externaldrive.fill.badge.icloud" : "externaldrive.fill")
            }
            if state.isReceiving {
                Text("\(Int(state.receivingProgress * 100))%")
                    .font(.caption2.monospacedDigit())
            }
        }
        .help(state.statusDescription)
    }
}

struct MenuBarPopoverContent: View {
    @ObservedObject var state: MenuBarState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            statusSection
            Divider()
            actionsSection
        }
        .frame(width: 260)
        .padding(.vertical, 4)
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 6) {
            if state.isReceiving {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Receiving from \(state.connectedDeviceName ?? "iPhone")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: state.receivingProgress)
                        .tint(.accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            } else {
                Text("No active backup sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            MenuBarActionButton(title: "Open Dashboard", icon: "gauge") {
                state.openDashboard()
            }
            MenuBarActionButton(title: "Change Backup Folder", icon: "folder") {
                state.changeBackupFolder()
            }
            Divider()
            MenuBarActionButton(title: "Quit iCherri", icon: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
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
    @Published var isReceiving = false
    @Published var receivingProgress: Double = 0
    @Published var connectedDeviceName: String?
    @Published var isDashboardOpen = false

    var statusDescription: String {
        if isReceiving { return "Receiving backup…" }
        return "Ready to receive"
    }

    var statusColor: Color {
        isReceiving ? .green : .secondary
    }

    func openDashboard() {
        // Posts notification to open main window
        NotificationCenter.default.post(name: .openDashboard, object: nil)
    }

    func changeBackupFolder() {
        NotificationCenter.default.post(name: .changeBackupFolder, object: nil)
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("iCherri.openDashboard")
    static let changeBackupFolder = Notification.Name("iCherri.changeBackupFolder")
    static let receiverDataDidChange = Notification.Name("iCherri.receiverDataDidChange")
}
