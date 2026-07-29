import SwiftUI
import ServiceManagement
import ICherriDesignSystem

struct SettingsView: View {
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()
    
    @State private var backupPath: String = AppCoordinator.shared.backupFolder.path
    @State private var pairedDevices: [PairedDeviceRecord] = []
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            devicesTab
                .tabItem {
                    Label("Paired Devices", systemImage: "iphone")
                }
                .tag(1)
        }
        .frame(width: 480, height: 350)
        .padding()
        .onAppear {
            loadDevices()
            
            // Listen to folder changes to update path label in real-time
            NotificationCenter.default.addObserver(
                forName: .changeBackupFolder,
                object: nil,
                queue: .main
            ) { _ in
                self.backupPath = AppCoordinator.shared.backupFolder.path
            }
        }
    }
    
    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)
                .padding(.bottom, 5)
            
            // Launch at Login
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch iCherri at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        toggleLaunchAtLogin(newValue)
                    }
                ))
                .toggleStyle(.checkbox)
                
                Text("Automatically start iCherri when you log into your Mac to keep receiver online.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Backup Folder
            VStack(alignment: .leading, spacing: 8) {
                Text("Backup Folder Location")
                    .font(.subheadline.bold())
                
                HStack(spacing: 12) {
                    Text(backupPath)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    Button("Change...") {
                        AppCoordinator.shared.selectBackupFolder()
                    }
                }
                
                Text("All backed up photos and videos from your devices will be stored in this folder.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var devicesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paired Devices")
                .font(.headline)
            
            Text("These devices are allowed to back up to this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if pairedDevices.isEmpty {
                VStack {
                    Spacer()
                    Text("No paired devices")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(pairedDevices, id: \.deviceId) { device in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.deviceName)
                                    .font(.subheadline.weight(.semibold))
                                Text("ID: \(device.deviceId)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                removeDevice(device)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red.opacity(0.15))
                            .foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding()
    }
    
    private func loadDevices() {
        do {
            self.pairedDevices = try DatabaseManager.shared.fetchAllDevices()
        } catch {
            print("Failed to fetch paired devices for settings: \(error)")
        }
    }
    
    private func removeDevice(_ device: PairedDeviceRecord) {
        let alert = NSAlert()
        alert.messageText = "Delete Paired Device?"
        alert.informativeText = "Are you sure you want to remove \(device.deviceName)? This removes its backup history, active sessions, and failure logs from this Mac."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task {
                do {
                    let tempPaths = try await DatabaseManager.shared.deletePairedDevice(deviceId: device.deviceId)
                    let keychain = MacKeychainStore()
                    try? keychain.deleteTrustToken(for: device.deviceId)
                    for path in tempPaths {
                        try? FileManager.default.removeItem(atPath: path)
                    }
                    
                    // Refresh devices list
                    loadDevices()
                    
                    // Post notification to trigger dashboard refresh
                    NotificationCenter.default.post(name: .receiverDataDidChange, object: nil)
                } catch {
                    print("Failed to delete device in settings: \(error)")
                }
            }
        }
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to change login item status: \(error)")
                // Revert toggle state if it failed
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
