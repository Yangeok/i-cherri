import SwiftUI
import Network
import ICherriProtocol
import ICherriDesignSystem
import Inject
import Factory
import CryptoKit
import ActivityKit


// Onboarding + pairing + backup trigger dashboard for iOS.
public struct BackupDashboardView: View {
    @ObserveInjection var inject
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = BackupDashboardViewModel()
    @State private var isTargetPickerPresented = false
    @State private var backupSheetDetent: PresentationDetent = .large

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                ScrollView {
                    VStack(spacing: 28) {
                        permissionSection
                        if let suggestedTarget = viewModel.suggestedSwitchTarget {
                            switchSuggestionBanner(for: suggestedTarget)
                        }
                        pairingSection
                        if viewModel.isPaired {
                            backupTriggerSection
                        }
                    }
                    .padding()
                }
            }
        }
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshReceivers()
                await viewModel.reevaluateAutomaticBackup()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.activeBackupProgressViewModel != nil },
                set: { isPresented in
                    if !isPresented && !viewModel.isBackupSheetLocked {
                        viewModel.dismissBackupProgress()
                    }
                }
            )
        ) {
            if let progressViewModel = viewModel.activeBackupProgressViewModel {
                NavigationStack {
                    BackupProgressView(viewModel: progressViewModel)
                }
                .presentationDetents([.height(88), .large], selection: $backupSheetDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(viewModel.isBackupSheetLocked)
                .onAppear {
                    backupSheetDetent = .large
                }
            }
        }
        .confirmationDialog(
            "Choose Backup Target",
            isPresented: $isTargetPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(viewModel.availableSwitchTargets) { receiver in
                Button(receiver.name) {
                    Task { await viewModel.pair(with: receiver) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pick a different Mac receiver for the next backup.")
        }
        .enableInjection()
    }

    // MARK: - Sections

    private var permissionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("Photo Library", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                permissionRow(
                    title: "Photos Access",
                    status: viewModel.photoPermissionStatus,
                    action: { await viewModel.requestPhotoPermission() }
                )
                permissionRow(
                    title: "Local Network",
                    status: viewModel.localNetworkStatus,
                    action: nil
                )
            }
        } label: {
            Label("Permissions", systemImage: "lock.shield")
        }
        .groupBoxStyle(.automatic)
    }

    private var pairingSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack {
                    Text("Nearby Mac receivers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.isBrowsing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Button {
                        Task { await viewModel.refreshReceivers() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPairing || viewModel.isBackingUp)
                }

                if let receiverName = viewModel.pairedReceiverName {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Backup Target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(receiverName)
                                    .font(.subheadline.weight(.semibold))
                                Circle()
                                    .fill(viewModel.pairedReceiverIsOnline ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.pairedReceiverIsOnline ? "Online" : "Offline")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Change") { isTargetPickerPresented = true }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isPairing || viewModel.isBackingUp || viewModel.availableSwitchTargets.isEmpty)
                        Button("Forget") { viewModel.clearPairedReceiver() }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isPairing || viewModel.isBackingUp)
                    }
                }
                if viewModel.discoveredReceivers.isEmpty {
                    if viewModel.isBrowsing {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Looking for Mac receivers…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("No receivers found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                } else {
                    ForEach(viewModel.discoveredReceivers) { receiver in
                        receiverRow(receiver)
                    }
                    .opacity(viewModel.isBrowsing ? 0.7 : 1.0)
                }
                if let message = viewModel.pairingStatusMessage {
                    if !(viewModel.isPaired && !viewModel.pairedReceiverIsOnline) {
                        Label(message, systemImage: viewModel.isPaired ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(viewModel.isPaired ? .green : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let errorMessage = viewModel.pairingErrorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            Label("Available Receivers", systemImage: "macbook.and.iphone")
        }
    }

    private var backupTriggerSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { viewModel.isAutoBackupEnabled },
                    set: { isEnabled in
                        Task { await viewModel.setAutoBackupEnabled(isEnabled) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic Backup")
                            .font(.headline)
                        Text("Runs when battery is at least 20% and Wi-Fi is available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let autoBackupStatusSummary = viewModel.autoBackupStatusSummary {
                    autoBackupStatusCard(autoBackupStatusSummary)
                }

                if let autoBackupEligibilityMessage = viewModel.autoBackupEligibilityMessage {
                    Label(autoBackupEligibilityMessage, systemImage: "bolt.horizontal.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let autoBackupRecentResultMessage = viewModel.autoBackupRecentResultMessage {
                    Label(autoBackupRecentResultMessage, systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let autoBackupLastSuccessMessage = viewModel.autoBackupLastSuccessMessage {
                    Label(autoBackupLastSuccessMessage, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let autoBackupNextEvaluationMessage = viewModel.autoBackupNextEvaluationMessage {
                    Label(autoBackupNextEvaluationMessage, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let receiverName = viewModel.pairedReceiverName {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: viewModel.pairedReceiverIsOnline ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(viewModel.pairedReceiverIsOnline ? .green : .orange)
                            Text(viewModel.pairedReceiverIsOnline ? "Connected to \(receiverName)" : "Disconnected from \(receiverName)")
                                .font(.subheadline)
                                .foregroundStyle(viewModel.pairedReceiverIsOnline ? .primary : .secondary)
                            Spacer()
                        }

                        if viewModel.pairedReceiverIsOnline {
                            if let backupCoverageSummary = viewModel.backupCoverageSummary,
                               let backupCoverageProgress = viewModel.backupCoverageProgress {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Library Coverage")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(backupCoverageSummary)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }

                                    ProgressView(value: backupCoverageProgress)
                                        .tint(.green)
                                }
                            }
                        } else {
                            Text("Make sure your Mac is active and on the same network.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button(action: { Task { await viewModel.startBackup() } }) {
                    Label("Start Backup", systemImage: "arrow.up.to.line.compact")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBackingUp || !viewModel.pairedReceiverIsOnline)
                if let backupStatusMessage = viewModel.backupStatusMessage {
                    Label(backupStatusMessage, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } label: {
            Label("Backup", systemImage: "externaldrive.fill.badge.icloud")
        }
    }

    private func switchSuggestionBanner(for target: DiscoveredReceiver) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Offline")
                    .font(.subheadline.weight(.bold))
                Text("기존 백업 대상(\(viewModel.pairedReceiverName ?? ""))을 찾을 수 없습니다. 주변에 감지된 '\(target.name)'으로 백업 대상을 전환할까요?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("전환") {
                Task { await viewModel.pair(with: target) }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.isPairing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.accentColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func permissionRow(title: String, status: PermissionStatus, action: (() async -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .denied:
                Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                    .font(.caption)
                    .buttonStyle(.bordered)
            case .unknown:
                if let action {
                    Button("Allow") { Task { await action() } }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                } else {
                    ProgressView()
                }
            }
        }
    }

    private func receiverRow(_ receiver: DiscoveredReceiver) -> some View {
        HStack {
            Image(systemName: "desktopcomputer")
            VStack(alignment: .leading, spacing: 2) {
                Text(receiver.name)
                    .font(.subheadline)
                if viewModel.isPaired && viewModel.pairedReceiverName == receiver.name {
                    Text("Current backup target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.isPaired && viewModel.pairedReceiver?.id == receiver.id {
                Label("Current", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(viewModel.isPaired ? "Switch Target" : "Connect") { Task { await viewModel.pair(with: receiver) } }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isPairing || viewModel.isBackingUp)
            }
        }
        .padding(.vertical, 4)
    }

    private func autoBackupStatusCard(_ status: AutoBackupStatusViewModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbolName)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.subheadline.weight(.semibold))
                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ViewModel

enum PermissionStatus { case granted, denied, unknown }

enum UploadConcurrencyPolicy {
    static let hardCap = 4

    static func recommendedConcurrency(for assets: ArraySlice<AssetMetadata>, maxAllowed: Int = hardCap) -> Int {
        let candidates = Array(assets)
        guard !candidates.isEmpty else { return 1 }

        let cappedMax = max(1, min(maxAllowed, hardCap))
        let videoCount = candidates.filter { $0.mediaType == .video }.count
        let hugeAssetCount = candidates.filter { $0.byteSize >= 500_000_000 }.count
        let largeAssetCount = candidates.filter { $0.byteSize >= 25_000_000 }.count
        let unknownSizeCount = candidates.filter { $0.byteSize <= 0 }.count
        let averageByteSize = candidates.reduce(Int64(0)) { $0 + max($1.byteSize, 0) } / Int64(max(candidates.count, 1))

        if videoCount >= 2 || hugeAssetCount > 0 {
            return min(2, cappedMax)
        }

        if videoCount == 1 {
            return min(2, cappedMax)
        }

        if largeAssetCount >= 3 || unknownSizeCount > candidates.count / 2 {
            return min(2, cappedMax)
        }

        if candidates.count >= 20 && averageByteSize > 0 && averageByteSize <= 8_000_000 {
            return min(4, cappedMax)
        }

        return min(3, cappedMax)
    }
}

@MainActor
final class BackupDashboardViewModel: ObservableObject {
    private static let maxConcurrentUploads = UploadConcurrencyPolicy.hardCap

    @Published var photoPermissionStatus: PermissionStatus = .unknown
    @Published var localNetworkStatus: PermissionStatus = .unknown
    @Published var discoveredReceivers: [DiscoveredReceiver] = []
    @Published var pairedReceiver: DiscoveredReceiver?
    @Published var pairedReceiverName: String?
    @Published var isPaired = false
    @Published var isPairing = false
    @Published var isBackingUp = false
    @Published var pairingStatusMessage: String?
    @Published var pairingErrorMessage: String?
    @Published var backupStatusMessage: String?
    @Published var isAutoBackupEnabled = false
    @Published var autoBackupEligibilityMessage: String?
    @Published var autoBackupStatusSummary: AutoBackupStatusViewModel?
    @Published var autoBackupRecentResultMessage: String?
    @Published var autoBackupLastSuccessMessage: String?
    @Published var autoBackupNextEvaluationMessage: String?
    @Published var activeBackupProgressViewModel: BackupProgressViewModel?
    @Published var backupCoverageSummary: String?
    @Published var backupCoverageProgress: Double?
    @Published var isBrowsing = false
    private var pingTimer: Task<Void, Never>?

    var pairedReceiverIsOnline: Bool {
        guard let name = pairedReceiverName else { return false }
        return discoveredReceivers.contains(where: { $0.name == name })
    }

    var suggestedSwitchTarget: DiscoveredReceiver? {
        guard isPaired && !pairedReceiverIsOnline else { return nil }
        return availableSwitchTargets.first
    }

    func startPingTimer() {
        pingTimer?.cancel()
        pingTimer = Task {
            // Send an initial ping immediately on timer start
            await sendPingToReceiver()
            
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                    await sendPingToReceiver()
                } catch {
                    break
                }
            }
        }
    }

    func stopPingTimer() {
        pingTimer?.cancel()
        pingTimer = nil
    }

    private func sendPingToReceiver() async {
        guard isPaired, pairedReceiverIsOnline,
              let receiverURLString = UserDefaults.standard.string(forKey: receiverURLKey),
              let receiverURL = URL(string: receiverURLString)
        else { return }

        let deviceID = persistentDeviceID()

        do {
            struct DevicePingRequest: Codable {
                let deviceID: String
            }
            let pingReq = DevicePingRequest(deviceID: deviceID)
            guard let url = URL(string: "\(receiverURLString)/devices/ping") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 4
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(pingReq)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode >= 400 {
                    let errMsg = String(data: data, encoding: .utf8) ?? "No response body"
                    print("[Ping] Failed to send heartbeat. HTTP \(http.statusCode): \(errMsg)")
                } else {
                    print("[Ping] Successfully sent heartbeat ping to receiver")
                }
            } else {
                print("[Ping] Successfully sent heartbeat ping to receiver")
            }
        } catch {
            print("[Ping] Failed to send heartbeat: \(error)")
        }
    }

    @Injected(\.photoLibraryScanner) private var scanner
    @Injected(\.photoLibraryScanIndexStore) private var scanIndexStore
    @Injected(\.bonjourBrowser) private var bonjourBrowser
    @Injected(\.keychainStore) private var keychainStore
    @Injected(\.autoBackupStore) private var autoBackupStore
    @Injected(\.autoBackupScheduler) private var autoBackupScheduler
    @Injected(\.autoBackupEngine) private var autoBackupEngine
    @Injected(\.autoBackupPolicyEvaluator) private var autoBackupPolicyEvaluator
    private let trustTokenKey = "iCherriTrustToken"
    private let receiverIDKey = "iCherriReceiverID"
    private let receiverURLKey = "iCherriReceiverURL"
    private let receiverNameKey = "iCherriReceiverName"

    var isBackupSheetLocked: Bool {
        guard let activeBackupProgressViewModel else { return false }
        return isBackingUp && !activeBackupProgressViewModel.isComplete
    }

    var availableSwitchTargets: [DiscoveredReceiver] {
        discoveredReceivers.filter { receiver in
            guard let currentID = pairedReceiver?.id else {
                return pairedReceiverName != receiver.name
            }
            return receiver.id != currentID
        }
    }

    func onAppear() async {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updatePhotoPermission()
        restorePairingState()
        await loadAutoBackupPolicy()
        await syncAutoBackupReceiverSelectionFromDefaults()
        scanIndexStore.startObserving()
        bonjourBrowser.startBrowsing()
        // Observe browser changes
        Task { @MainActor in
            for await receivers in bonjourBrowser.$discoveredReceivers.values {
                self.discoveredReceivers = receivers
                self.localNetworkStatus = receivers.isEmpty ? self.localNetworkStatus : .granted
                
                // Auto-Healing: Automatically detect and update the stored URL if the Mac's IP/port has changed
                if let pairedName = self.pairedReceiverName,
                   let matchingReceiver = receivers.first(where: { $0.name == pairedName }) {
                    self.pairedReceiver = matchingReceiver
                    Task {
                        do {
                            let newBaseURL = try await Self.resolveEndpoint(matchingReceiver.endpoint)
                            let currentStoredURL = UserDefaults.standard.string(forKey: self.receiverURLKey)
                            if newBaseURL.absoluteString != currentStoredURL {
                                UserDefaults.standard.set(newBaseURL.absoluteString, forKey: self.receiverURLKey)
                                print("[Auto-Healing] Automatically updated receiver URL to \(newBaseURL.absoluteString)")
                            }
                            // Start pinging immediately once the endpoint is resolved to the new URL
                            self.startPingTimer()
                        } catch {
                            print("[Auto-Healing] Failed to auto-resolve endpoint: \(error)")
                        }
                    }
                } else if let pairedReceiverID = UserDefaults.standard.string(forKey: self.receiverIDKey) {
                    self.pairedReceiver = receivers.first(where: { $0.id == pairedReceiverID })
                    if let endpoint = self.pairedReceiver?.endpoint {
                        Task {
                            do {
                                let newBaseURL = try await Self.resolveEndpoint(endpoint)
                                UserDefaults.standard.set(newBaseURL.absoluteString, forKey: self.receiverURLKey)
                                self.startPingTimer()
                            } catch {
                                print("[Auto-Healing] Failed to resolve matched receiver by ID: \(error)")
                            }
                        }
                    }
                } else if let pairedReceiverName {
                    self.pairedReceiver = receivers.first(where: { $0.name == pairedReceiverName })
                    if let endpoint = self.pairedReceiver?.endpoint {
                        Task {
                            do {
                                let newBaseURL = try await Self.resolveEndpoint(endpoint)
                                UserDefaults.standard.set(newBaseURL.absoluteString, forKey: self.receiverURLKey)
                                self.startPingTimer()
                            } catch {
                                print("[Auto-Healing] Failed to resolve matched receiver by name: \(error)")
                            }
                        }
                    }
                }
                
                Task {
                    await self.reevaluateAutomaticBackup()
                }
            }
        }
        Task { @MainActor in
            for await status in bonjourBrowser.$status.values {
                switch status {
                case .ready:
                    self.localNetworkStatus = .granted
                    self.isBrowsing = false
                case .failed:
                    self.localNetworkStatus = .denied
                    self.isBrowsing = false
                case .browsing:
                    self.isBrowsing = true
                    if self.localNetworkStatus != .granted {
                        self.localNetworkStatus = .unknown
                    }
                case .idle:
                    self.isBrowsing = false
                    if self.localNetworkStatus != .granted {
                        self.localNetworkStatus = .unknown
                    }
                }
                Task {
                    await self.reevaluateAutomaticBackup()
                }
            }
        }
        Task {
            await reevaluateAutomaticBackup()
        }
    }

    func requestPhotoPermission() async {
        let status = await scanner.requestAuthorization()
        photoPermissionStatus = permissionStatus(for: status)
    }

    func refreshReceivers() async {
        bonjourBrowser.refreshBrowsing()
        if localNetworkStatus != .granted {
            localNetworkStatus = .unknown
        }
        pairingStatusMessage = isPaired
            ? pairedReceiverName.map { "Connected to \($0)." }
            : "Refreshing available receivers..."
        Task {
            await reevaluateAutomaticBackup()
        }
    }

    func setAutoBackupEnabled(_ isEnabled: Bool) async {
        isAutoBackupEnabled = isEnabled
        let currentPolicy = await autoBackupStore.loadPolicy()
        let updatedPolicy = AutoBackupPolicy(
            isEnabled: isEnabled,
            minimumBatteryPercent: currentPolicy.minimumBatteryPercent,
            requiresWiFiEnabled: currentPolicy.requiresWiFiEnabled,
            blocksOnLowPowerMode: currentPolicy.blocksOnLowPowerMode,
            pauseThermalThreshold: currentPolicy.pauseThermalThreshold,
            stagedStorageLimitBytes: currentPolicy.stagedStorageLimitBytes
        )
        await autoBackupStore.savePolicy(updatedPolicy)
        autoBackupScheduler.scheduleNextEvaluation()
        Task {
            await reevaluateAutomaticBackup()
        }
    }

    func pair(with receiver: DiscoveredReceiver) async {
        let previousReceiver = pairedReceiver
        let previousReceiverName = pairedReceiverName
        let previousIsPaired = isPaired
        let previousStatusMessage = pairingStatusMessage

        isPairing = true
        pairingErrorMessage = nil
        pairingStatusMessage = "Connecting to \(receiver.name)..."
        defer { isPairing = false }

        // Resolve endpoint and send pair request to Mac server
        do {
            let baseURL = try await Self.resolveEndpoint(receiver.endpoint)
            let device = currentDeviceInfo()
            let pairRequest = PairingStartRequest(device: device)
            
            guard let url = URL(string: "\(baseURL.absoluteString)/pair") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(device.deviceID, forHTTPHeaderField: "X-iCherri-Device-ID")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(pairRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let confirmResponse = try decoder.decode(PairingConfirmResponse.self, from: data)
                
                // Store trust token for future requests
                UserDefaults.standard.set(confirmResponse.trustToken, forKey: trustTokenKey)
                UserDefaults.standard.set(receiver.id, forKey: receiverIDKey)
                UserDefaults.standard.set(baseURL.absoluteString, forKey: receiverURLKey)
                UserDefaults.standard.set(receiver.name, forKey: receiverNameKey)

                pairedReceiver = receiver
                pairedReceiverName = receiver.name
                isPaired = true
                pairingStatusMessage = "Connected to \(receiver.name)."
                await autoBackupStore.saveReceiverSelection(
                    AutoBackupReceiverSelection(
                        receiverID: receiver.id,
                        receiverName: receiver.name,
                        receiverURLString: baseURL.absoluteString,
                        trustTokenStorageKey: trustTokenKey
                    )
                )
                self.startPingTimer()
                Task {
                    await reevaluateAutomaticBackup()
                }
                print("[Pair] Successfully paired with \(receiver.name), token: \(confirmResponse.trustToken.prefix(8))...")
            } else {
                print("[Pair] Server returned error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                pairedReceiver = previousReceiver
                pairedReceiverName = previousReceiverName
                isPaired = previousIsPaired
                pairingStatusMessage = previousStatusMessage
                pairingErrorMessage = "Pairing failed. Receiver returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)."
            }
        } catch {
            print("[Pair] Failed to pair: \(error)")
            pairedReceiver = previousReceiver
            pairedReceiverName = previousReceiverName
            isPaired = previousIsPaired
            pairingStatusMessage = previousStatusMessage
            pairingErrorMessage = "Pairing failed: \(error.localizedDescription)"
        }
    }

    func clearPairedReceiver() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: trustTokenKey)
        defaults.removeObject(forKey: receiverIDKey)
        defaults.removeObject(forKey: receiverURLKey)
        defaults.removeObject(forKey: receiverNameKey)

        pairedReceiver = nil
        pairedReceiverName = nil
        isPaired = false
        pairingStatusMessage = "Choose a Mac receiver to use as the backup target."
        backupStatusMessage = nil
        backupCoverageSummary = nil
        backupCoverageProgress = nil
        bonjourBrowser.refreshBrowsing()
        autoBackupEligibilityMessage = "Automatic backup is waiting for a backup target."
        self.stopPingTimer()
        Task {
            await autoBackupStore.saveReceiverSelection(nil)
            await refreshAutoBackupStatusPresentation(fallbackMessage: self.autoBackupEligibilityMessage)
        }
    }

    func reevaluateAutomaticBackup() async {
        guard photoPermissionStatus == .granted else {
            autoBackupEligibilityMessage = "Automatic backup needs Photos access."
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        let policy = await autoBackupStore.loadPolicy()
        isAutoBackupEnabled = policy.isEnabled

        guard policy.isEnabled else {
            autoBackupEligibilityMessage = "Automatic backup is off."
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        let runtimeSnapshot = makeAutoBackupRuntimeSnapshot()
        let eligibility = autoBackupPolicyEvaluator.evaluate(policy: policy, runtimeSnapshot: runtimeSnapshot)

        guard let receiverID = UserDefaults.standard.string(forKey: receiverIDKey), !receiverID.isEmpty else {
            autoBackupEligibilityMessage = "Automatic backup is waiting for a backup target."
            autoBackupScheduler.scheduleNextEvaluation()
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        guard eligibility.isEligible else {
            autoBackupEligibilityMessage = eligibilityMessage(for: eligibility.reason)
            autoBackupScheduler.scheduleNextEvaluation()
            _ = try? await autoBackupEngine.evaluateAndPrepareRun(
                receiverID: receiverID,
                receiverName: pairedReceiverName,
                runtimeSnapshot: runtimeSnapshot,
                runAssets: []
            )
            await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
            return
        }

        let device = currentDeviceInfo()
        let scanPlan = await scanIndexStore.makeScanPlan(scanner: scanner, deviceID: device.deviceID)
        if let preparedRun = try? await autoBackupEngine.evaluateAndPrepareRun(
            receiverID: receiverID,
            receiverName: pairedReceiverName,
            runtimeSnapshot: runtimeSnapshot,
            runAssets: scanPlan.runAssets
        ) {
            autoBackupEligibilityMessage = scanPlan.runAssets.isEmpty
                ? "Automatic backup is ready. No changed assets are waiting."
                : "Automatic backup prepared \(preparedRun.assetRecords.count) item(s)."
        } else {
            autoBackupEligibilityMessage = "Automatic backup could not prepare a run."
        }
        autoBackupScheduler.scheduleNextEvaluation()
        await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
    }

    func startBackup() async {
        guard photoPermissionStatus == .granted else {
            backupStatusMessage = "Allow Photos access before starting backup."
            return
        }
        guard
            let trustToken = UserDefaults.standard.string(forKey: trustTokenKey),
            !trustToken.isEmpty
        else {
            backupStatusMessage = "Connect to a Mac receiver first."
            return
        }

        isBackingUp = true
        backupStatusMessage = "Scanning photo library..."
        let device = currentDeviceInfo()
        let progressViewModel = BackupProgressViewModel(totalCount: 0)
        progressViewModel.setPhase(.scanning)
        progressViewModel.onRetryFailedUploads = { [weak self] assetIDs in
            guard let self else { return }
            Task { @MainActor in
                await self.retryFailedUploads(assetIDs: assetIDs)
            }
        }
        progressViewModel.onRetryUpload = { [weak self] assetLocalID in
            guard let self else { return }
            Task { @MainActor in
                await self.retryFailedUploads(assetIDs: [assetLocalID])
            }
        }
        progressViewModel.update(
            filename: "Scanning photo library...",
            completed: 0,
            success: 0,
            duplicates: 0,
            failed: 0,
            overallBackedUpCount: 0,
            phase: .scanning,
            bytesPerSecond: 0,
            sentBytes: 0,
            totalBytes: 0,
            activeUploads: 0,
            activeUploadItems: [],
            failedUploadItems: []
        )
        activeBackupProgressViewModel = progressViewModel
        let pairedReceiverSnapshot = pairedReceiver
        let pairedReceiverIDSnapshot = UserDefaults.standard.string(forKey: receiverIDKey)
        let pairedReceiverNameSnapshot = pairedReceiverName
        let discoveredReceiversSnapshot = discoveredReceivers
        let storedReceiverURLString = UserDefaults.standard.string(forKey: receiverURLKey)

        let backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ManualBackup") {
            // System expires this background execution budget
        }

        let backupTask = Task.detached(priority: .userInitiated) { [maxConcurrentUploads = Self.maxConcurrentUploads, backgroundTaskID] in
            var executedScanMode: PhotoLibraryScanPlan.Mode = .incremental
            defer {
                Task { @MainActor in
                    self.isBackingUp = false
                    if #available(iOS 16.2, *) {
                        BackupLiveActivityManager.shared.stop()
                    }
                    if backgroundTaskID != .invalid {
                        UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    }
                }
            }

            do {
                try Task.checkCancellation()

                let scanPlan = await self.scanIndexStore.makeScanPlan(scanner: self.scanner, deviceID: device.deviceID)
                executedScanMode = scanPlan.mode
                let runAssets = scanPlan.runAssets

                await MainActor.run {
                    if #available(iOS 16.2, *) {
                        let initialCompleted = max(scanPlan.libraryAssetCount - scanPlan.runAssetCount, 0)
                        BackupLiveActivityManager.shared.start(
                            deviceName: device.deviceName,
                            completedCount: initialCompleted,
                            totalCount: scanPlan.libraryAssetCount
                        )
                    }
                    progressViewModel.setTotalCount(scanPlan.runAssetCount)
                    progressViewModel.setTotalBytes(scanPlan.runAssetBytes)
                    progressViewModel.totalCount = scanPlan.libraryAssetCount
                    progressViewModel.overallBackedUpCount = max(scanPlan.libraryAssetCount - scanPlan.runAssetCount, 0)
                }

                try Task.checkCancellation()

                if runAssets.isEmpty {
                    await MainActor.run {
                        progressViewModel.update(
                            filename: scanPlan.mode == .incremental ? "Nothing new to back up" : "No media found",
                            completed: 0,
                            success: 0,
                            duplicates: 0,
                            failed: 0,
                            overallBackedUpCount: 0,
                            phase: .complete,
                            bytesPerSecond: 0,
                            totalBytes: scanPlan.runAssetBytes
                        )
                        self.backupStatusMessage = scanPlan.mode == .incremental
                            ? "No changed photos or videos need backup."
                            : "No photos or videos found to back up."
                        self.scanIndexStore.finishBackupRun(mode: scanPlan.mode)
                    }
                    return
                }

                let progressCoordinator = await MainActor.run {
                    BackupUploadProgressCoordinator(
                        viewModel: progressViewModel,
                        totalExpectedBytes: scanPlan.runAssetBytes,
                        totalCount: progressViewModel.totalCount
                    )
                }

                await progressCoordinator.updateSnapshot(
                    filename: "Checking existing backups...",
                    completed: 0,
                    success: 0,
                    duplicates: 0,
                    failed: 0,
                    overallBackedUpCount: 0,
                    phase: .checking,
                    bytesPerSecond: 0
                )

                let receiverURL = try await Self.resolveReceiverURLForBackup(
                    pairedReceiver: pairedReceiverSnapshot,
                    pairedReceiverID: pairedReceiverIDSnapshot,
                    pairedReceiverName: pairedReceiverNameSnapshot,
                    discoveredReceivers: discoveredReceiversSnapshot,
                    storedReceiverURLString: storedReceiverURLString
                )

                let backupClient = BackupClient(receiverBaseURL: receiverURL, device: device, trustToken: trustToken)
                let backupRunID = UUID().uuidString
                let batchResponse = try await backupClient.checkBatch(
                    backupRunID: backupRunID,
                    candidates: runAssets,
                    totalAssetCount: scanPlan.libraryAssetCount,
                    totalAssetBytes: scanPlan.libraryAssetBytes
                )
                let assetIndex = Dictionary(uniqueKeysWithValues: runAssets.map { ($0.assetLocalID, $0) })

                let duplicateAssetIDs = Set(batchResponse.alreadyBackedUp + batchResponse.duplicates)
                let reconcileState = BackupRunReconcileState(
                    libraryAssetCount: scanPlan.libraryAssetCount,
                    runAssetCount: scanPlan.runAssetCount,
                    duplicateCount: duplicateAssetIDs.count,
                    failedAssetIDs: Set(batchResponse.unsupported)
                )
                var pendingAssetIDs: Set<String> = []

                let duplicateBytes = (batchResponse.alreadyBackedUp + batchResponse.duplicates)
                    .compactMap { assetIndex[$0]?.byteSize }
                    .reduce(Int64(0), +)
                await MainActor.run {
                    if scanPlan.mode == .full {
                        self.updateBackupCoverage(backedUpCount: duplicateAssetIDs.count, totalCount: scanPlan.libraryAssetCount)
                    }
                    self.scanIndexStore.markSucceeded(assetIDs: batchResponse.alreadyBackedUp + batchResponse.duplicates)
                }
                var initialFailures = batchResponse.unsupported.map { assetLocalID in
                    FailedUploadProgressItem(
                        id: "unsupported-\(assetLocalID)",
                        filename: assetIndex[assetLocalID]?.originalFilename ?? assetLocalID,
                        reason: "Unsupported media type.",
                        retryAssetLocalID: nil
                    )
                }

                for requirement in batchResponse.requiredUploads {
                    guard let metadata = assetIndex[requirement.assetLocalID] else {
                        _ = await reconcileState.recordFailure(assetLocalID: requirement.assetLocalID)
                        initialFailures.append(
                            FailedUploadProgressItem(
                                id: requirement.assetLocalID,
                                filename: requirement.assetLocalID,
                                reason: "Asset metadata could not be resolved before upload.",
                                retryAssetLocalID: requirement.assetLocalID
                            )
                        )
                        continue
                    }
                    pendingAssetIDs.insert(metadata.assetLocalID)
                }

                let requiredUploadIDs = Array(pendingAssetIDs)
                await MainActor.run {
                    self.scanIndexStore.markRetryRequired(assetIDs: requiredUploadIDs)
                }

                let initialCounts = await reconcileState.snapshotCounts()
                await progressCoordinator.setInitialFailures(initialFailures)
                await progressCoordinator.setAcknowledgedBytes(duplicateBytes)
                await progressCoordinator.updateSnapshot(
                    filename: "Preparing uploads...",
                    completed: initialCounts.completed,
                    success: initialCounts.success,
                    duplicates: initialCounts.duplicates,
                    failed: initialCounts.failed,
                    overallBackedUpCount: initialCounts.overallBackedUpCount,
                    phase: pendingAssetIDs.isEmpty ? .checking : .uploading,
                    bytesPerSecond: 0
                )

                let maxReconcileRounds = 3
                var reconcileRound = 0

                while true {
                    if !pendingAssetIDs.isEmpty {
                        let roundAssets = pendingAssetIDs.sorted().compactMap { assetIndex[$0] }
                        let resolvedAssetIDs = Set(roundAssets.map(\.assetLocalID))
                        let unresolvedAssetIDs = pendingAssetIDs.subtracting(resolvedAssetIDs)
                        guard unresolvedAssetIDs.isEmpty else {
                            throw BackupRunReconcileError.unresolvedAssets(unresolvedAssetIDs.sorted())
                        }

                        try await self.uploadAssets(
                            pendingAssets: roundAssets,
                            receiverURL: receiverURL,
                            device: device,
                            trustToken: trustToken,
                            progressCoordinator: progressCoordinator,
                            maxConcurrentUploads: maxConcurrentUploads
                        ) { outcome in
                            switch outcome {
                            case .success(let assetLocalID, let filename):
                                let counts = await reconcileState.recordSuccess(assetLocalID: assetLocalID)
                                await MainActor.run {
                                    if scanPlan.mode == .full {
                                        self.updateBackupCoverage(backedUpCount: counts.overallBackedUpCount, totalCount: scanPlan.libraryAssetCount)
                                    }
                                    self.scanIndexStore.markSucceeded(assetIDs: [assetLocalID])
                                }
                                await progressCoordinator.finishAsset(
                                    assetLocalID: assetLocalID,
                                    filename: filename,
                                    completed: counts.completed,
                                    success: counts.success,
                                    duplicates: counts.duplicates,
                                    failed: counts.failed,
                                    overallBackedUpCount: counts.overallBackedUpCount
                                )
                            case .failure(let assetLocalID, let filename, let reason):
                                let counts = await reconcileState.recordFailure(assetLocalID: assetLocalID)
                                await progressCoordinator.finishAsset(
                                    assetLocalID: assetLocalID,
                                    filename: filename,
                                    completed: counts.completed,
                                    success: counts.success,
                                    duplicates: counts.duplicates,
                                    failed: counts.failed,
                                    overallBackedUpCount: counts.overallBackedUpCount
                                )
                                await progressCoordinator.recordFailure(
                                    assetLocalID: assetLocalID,
                                    filename: filename,
                                    reason: reason
                                )
                            }
                        }

                        pendingAssetIDs.removeAll()
                    }

                    let verifyingCounts = await reconcileState.snapshotCounts()
                    await progressCoordinator.updateSnapshot(
                        filename: "Verifying receiver snapshot...",
                        completed: verifyingCounts.completed,
                        success: verifyingCounts.success,
                        duplicates: verifyingCounts.duplicates,
                        failed: verifyingCounts.failed,
                        overallBackedUpCount: verifyingCounts.overallBackedUpCount,
                        phase: .checking,
                        bytesPerSecond: 0
                    )

                    let finalizeResponse = try await backupClient.finalizeBackupRun(backupRunID: backupRunID)
                    await reconcileState.setReceiverCompletedAssetCount(finalizeResponse.completedAssetCount)
                    let uploadedAssetIDs = await reconcileState.currentUploadedAssetIDs()
                    let missingAssetIDs = Set(finalizeResponse.missingAssetIDs)
                        .subtracting(duplicateAssetIDs)
                        .subtracting(uploadedAssetIDs)

                    guard !missingAssetIDs.isEmpty else { break }

                    reconcileRound += 1
                    guard reconcileRound <= maxReconcileRounds else {
                        throw BackupRunReconcileError.exceededRetryRounds(missingAssetIDs.sorted())
                    }

                    pendingAssetIDs = missingAssetIDs
                    let retryAssetIDs = Array(pendingAssetIDs)
                    await MainActor.run {
                        self.scanIndexStore.markRetryRequired(assetIDs: retryAssetIDs)
                    }

                    let retryCounts = await reconcileState.snapshotCounts()
                    await progressCoordinator.updateSnapshot(
                        filename: "Retrying \(pendingAssetIDs.count.formatted()) missing items...",
                        completed: retryCounts.completed,
                        success: retryCounts.success,
                        duplicates: retryCounts.duplicates,
                        failed: retryCounts.failed,
                        overallBackedUpCount: retryCounts.overallBackedUpCount,
                        phase: .uploading,
                        bytesPerSecond: 0
                    )
                }

                let finalCounts = await reconcileState.snapshotCounts()
                await MainActor.run {
                    if scanPlan.mode == .full {
                        self.updateBackupCoverage(backedUpCount: finalCounts.overallBackedUpCount, totalCount: scanPlan.libraryAssetCount)
                    }
                    self.scanIndexStore.finishBackupRun(mode: scanPlan.mode)
                    self.backupStatusMessage = "Backup complete. Uploaded \(finalCounts.success), skipped \(finalCounts.duplicates), failed \(finalCounts.failed)."
                    progressViewModel.setPhase(.complete)
                }
            } catch is CancellationError {
                let scanMode = executedScanMode
                await MainActor.run {
                    self.backupStatusMessage = "Backup canceled."
                    self.scanIndexStore.finishBackupRun(mode: scanMode)
                    self.activeBackupProgressViewModel = nil
                }
            } catch {
                print("[Backup] Backup run failed: \(error)")
                await MainActor.run {
                    let message = backupFailureReason(error)
                    self.backupStatusMessage = "Backup failed: \(message)"
                    progressViewModel.markRunFailed(message)
                }
            }
        }

        progressViewModel.bindCancellation(to: backupTask)
        await backupTask.value
    }

    func dismissBackupProgress() {
        activeBackupProgressViewModel = nil
    }

    func retryFailedUploads(assetIDs: [String]) async {
        let retryableIDs = Array(Set(assetIDs))
        guard !retryableIDs.isEmpty else { return }
        guard !isBackingUp else { return }

        scanIndexStore.markRetryRequired(assetIDs: retryableIDs)
        activeBackupProgressViewModel = nil
        backupStatusMessage = "Retrying failed uploads..."
        await startBackup()
    }

    private func updateBackupCoverage(backedUpCount: Int, totalCount: Int) {
        guard totalCount > 0 else {
            backupCoverageSummary = nil
            backupCoverageProgress = nil
            return
        }

        let clampedCount = min(max(backedUpCount, 0), totalCount)
        let percent = Int((Double(clampedCount) / Double(totalCount) * 100).rounded())
        backupCoverageProgress = Double(clampedCount) / Double(totalCount)
        backupCoverageSummary = "\(percent)% · \(clampedCount.formatted()) / \(totalCount.formatted())"
    }

    private func updatePhotoPermission() {
        let status = scanner.currentAuthorizationStatus()
        photoPermissionStatus = permissionStatus(for: status)
    }

    private func loadAutoBackupPolicy() async {
        let policy = await autoBackupStore.loadPolicy()
        isAutoBackupEnabled = policy.isEnabled
    }

    private func syncAutoBackupReceiverSelectionFromDefaults() async {
        guard
            let receiverID = UserDefaults.standard.string(forKey: receiverIDKey),
            !receiverID.isEmpty
        else {
            await autoBackupStore.saveReceiverSelection(nil)
            await refreshAutoBackupStatusPresentation(fallbackMessage: "Automatic backup is waiting for a backup target.")
            return
        }

        await autoBackupStore.saveReceiverSelection(
            AutoBackupReceiverSelection(
                receiverID: receiverID,
                receiverName: UserDefaults.standard.string(forKey: receiverNameKey),
                receiverURLString: UserDefaults.standard.string(forKey: receiverURLKey),
                trustTokenStorageKey: trustTokenKey
            )
        )
        await refreshAutoBackupStatusPresentation(fallbackMessage: autoBackupEligibilityMessage)
    }

    private func makeAutoBackupRuntimeSnapshot() -> AutoBackupRuntimeSnapshot {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryPercent = batteryLevel >= 0 ? Int((batteryLevel * 100).rounded()) : 100
        return AutoBackupRuntimeSnapshot(
            batteryLevelPercent: batteryPercent,
            isWiFiEnabled: localNetworkStatus == .granted,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalState: ProcessInfo.processInfo.thermalState,
            hasPairedReceiver: isPaired
        )
    }

    private func eligibilityMessage(for reason: AutoBackupEligibilityBlockReason?) -> String {
        switch reason {
        case .disabled:
            return "Automatic backup is off."
        case .batteryBelowMinimum:
            return "Automatic backup is waiting for battery to reach 20%."
        case .wiFiUnavailable:
            return "Automatic backup is waiting for Wi-Fi."
        case .receiverUnavailable:
            return "Automatic backup is waiting for a Mac receiver."
        case .lowPowerMode:
            return "Automatic backup is paused by Low Power Mode."
        case .thermal:
            return "Automatic backup is paused because the device is too warm."
        case nil:
            return "Automatic backup is ready."
        }
    }

    private func refreshAutoBackupStatusPresentation(fallbackMessage: String?) async {
        let receiverID = UserDefaults.standard.string(forKey: receiverIDKey)
        let activeRun: AutoBackupRun?
        if let receiverID, !receiverID.isEmpty {
            activeRun = await autoBackupStore.loadActiveRun(receiverID: receiverID)
        } else {
            activeRun = nil
        }
        let terminalRun = await autoBackupStore.loadMostRecentTerminalRun(receiverID: receiverID)
        let latestEvent = await autoBackupStore.loadLatestEvent(runID: activeRun?.runID ?? terminalRun?.runID)
        let nextEvaluationAt = await autoBackupStore.loadNextEvaluationDate()
        autoBackupStatusSummary = AutoBackupStatusViewModel.make(
            isEnabled: isAutoBackupEnabled,
            receiverName: pairedReceiverName,
            activeRun: activeRun,
            fallbackMessage: fallbackMessage,
            latestEvent: latestEvent
        )
        autoBackupRecentResultMessage = AutoBackupStatusViewModel.recentResultText(for: terminalRun)
        autoBackupLastSuccessMessage = AutoBackupStatusViewModel.lastSuccessText(for: terminalRun)
        autoBackupNextEvaluationMessage = AutoBackupStatusViewModel.nextEvaluationText(for: nextEvaluationAt)
    }

    private func permissionStatus(for status: PhotoLibraryAuthStatus) -> PermissionStatus {
        switch status {
        case .authorized, .limited:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        }
    }

    private func restorePairingState() {
        let defaults = UserDefaults.standard
        guard
            let trustToken = defaults.string(forKey: trustTokenKey),
            !trustToken.isEmpty
        else {
            pairedReceiver = nil
            pairedReceiverName = nil
            isPaired = false
            return
        }

        pairedReceiverName = defaults.string(forKey: receiverNameKey)
        isPaired = pairedReceiverName != nil
        pairingStatusMessage = pairedReceiverName.map { "Connected to \($0)." }
        if isPaired {
            startPingTimer()
        }
    }

    private func describeBackupError(_ error: Error) -> String {
        backupFailureReason(error)
    }

    private func uploadAssets(
        pendingAssets: [AssetMetadata],
        receiverURL: URL,
        device: DeviceInfo,
        trustToken: String,
        progressCoordinator: BackupUploadProgressCoordinator,
        maxConcurrentUploads: Int,
        onOutcome: @escaping @Sendable (UploadTaskOutcome) async -> Void
    ) async throws {
        guard !pendingAssets.isEmpty else { return }

        // Start background pre-hashing pipeline
        let scanner = PhotoLibraryScanner()
        let prehashTask = Task.detached(priority: .utility) {
            for metadata in pendingAssets {
                if Task.isCancelled { break }
                
                // Keep memory usage low: wait if cache is full
                while await PrehashCache.shared.isFull() {
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                }
                
                do {
                    if metadata.mediaType == .video {
                        // Stream hashing for videos to avoid memory loading
                        let (stream, _) = try await scanner.openInputStreamWithSize(for: metadata.assetLocalID)
                        stream.open()
                        var hasher = SHA256()
                        let bufSize = 65536
                        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
                        while stream.hasBytesAvailable {
                            if Task.isCancelled { break }
                            let n = stream.read(buf, maxLength: bufSize)
                            guard n > 0 else { break }
                            hasher.update(data: Data(bytes: buf, count: n))
                        }
                        buf.deallocate()
                        stream.close()
                        
                        if !Task.isCancelled {
                            let contentHash = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                            await PrehashCache.shared.setHash(contentHash, for: metadata.assetLocalID)
                        }
                    } else {
                        let data = try await scanner.fetchData(for: metadata.assetLocalID)
                        if Task.isCancelled { break }
                        let contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                        await PrehashCache.shared.setHash(contentHash, for: metadata.assetLocalID)
                        await PrehashCache.shared.setData(data, for: metadata.assetLocalID)
                    }
                } catch {
                    print("[Prehash] Failed to prehash \(metadata.originalFilename): \(error)")
                }
            }
        }
        defer { prehashTask.cancel() }

        try await withThrowingTaskGroup(of: UploadTaskOutcome.self) { group in
            var nextIndex = 0
            var activeTaskCount = 0

            func enqueueNextUpload() {
                guard nextIndex < pendingAssets.count else { return }
                let metadata = pendingAssets[nextIndex]
                nextIndex += 1
                activeTaskCount += 1

                group.addTask {
                    let taskBackupClient = BackupClient(
                        receiverBaseURL: receiverURL,
                        device: device,
                        trustToken: trustToken
                    )
                    let taskChunkSender = ChunkUploadSender(
                        receiverBaseURL: receiverURL,
                        device: device,
                        trustToken: trustToken
                    )
                    let taskProgress = AssetUploadProgressReporter(
                        assetLocalID: metadata.assetLocalID,
                        filename: metadata.originalFilename,
                        coordinator: progressCoordinator
                    )
                    await taskChunkSender.setProgressDelegate(taskProgress)
                    let uploadManager = ResumableUploadManager(
                        backupClient: taskBackupClient,
                        chunkSender: taskChunkSender,
                        scanner: PhotoLibraryScanner()
                    )

                    await progressCoordinator.beginAsset(
                        assetLocalID: metadata.assetLocalID,
                        filename: metadata.originalFilename,
                        expectedByteSize: metadata.byteSize
                    )

                    do {
                        _ = try await uploadManager.upload(
                            assetLocalID: metadata.assetLocalID,
                            metadata: metadata
                        )
                        return .success(assetLocalID: metadata.assetLocalID, filename: metadata.originalFilename)
                    } catch {
                        print("[Backup] Failed to upload \(metadata.originalFilename): \(error)")
                        return .failure(
                            assetLocalID: metadata.assetLocalID,
                            filename: metadata.originalFilename,
                            reason: backupFailureReason(error)
                        )
                    }
                }
            }

            let initialConcurrency = min(
                UploadConcurrencyPolicy.recommendedConcurrency(
                    for: pendingAssets[pendingAssets.startIndex...],
                    maxAllowed: maxConcurrentUploads
                ),
                pendingAssets.count
            )
            for _ in 0..<initialConcurrency {
                enqueueNextUpload()
            }

            while let outcome = try await group.next() {
                try Task.checkCancellation()
                activeTaskCount = max(activeTaskCount - 1, 0)
                await onOutcome(outcome)

                let desiredConcurrency = UploadConcurrencyPolicy.recommendedConcurrency(
                    for: pendingAssets[nextIndex...],
                    maxAllowed: maxConcurrentUploads
                )
                while activeTaskCount < desiredConcurrency && nextIndex < pendingAssets.count {
                    enqueueNextUpload()
                }
            }
        }
    }
    
    private func currentDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            deviceID: persistentDeviceID(),
            deviceName: UIDevice.current.name,
            platform: "iOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    private func persistentDeviceID() -> String {
        if let stored = try? keychainStore.loadDeviceID(), !stored.isEmpty {
            return stored
        }

        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        try? keychainStore.saveDeviceID(generated)
        return generated
    }

    private static func resolveReceiverURLForBackup(
        pairedReceiver: DiscoveredReceiver?,
        pairedReceiverID: String?,
        pairedReceiverName: String?,
        discoveredReceivers: [DiscoveredReceiver],
        storedReceiverURLString: String?
    ) async throws -> URL {
        // 1. First priority: Use the stored receiver URL (which is kept updated by Auto-Healing)
        if let storedReceiverURLString,
           let receiverURL = URL(string: storedReceiverURLString),
           !isLinkLocalReceiverURL(receiverURL) {
            return receiverURL
        }

        // 2. Second priority fallback: Dynamically resolve Bonjour endpoints if stored URL is unavailable or invalid
        if let pairedReceiver {
            do {
                return try await resolveEndpoint(pairedReceiver.endpoint)
            } catch {
                print("[resolveReceiverURL] Failed to resolve pairedReceiver endpoint: \(error)")
            }
        }

        if let pairedReceiverID,
           let discoveredReceiver = discoveredReceivers.first(where: { $0.id == pairedReceiverID }) {
            do {
                return try await resolveEndpoint(discoveredReceiver.endpoint)
            } catch {
                print("[resolveReceiverURL] Failed to resolve pairedReceiverID endpoint: \(error)")
            }
        }

        if let pairedReceiverName,
           let discoveredReceiver = discoveredReceivers.first(where: { $0.name == pairedReceiverName }) {
            do {
                return try await resolveEndpoint(discoveredReceiver.endpoint)
            } catch {
                print("[resolveReceiverURL] Failed to resolve pairedReceiverName endpoint: \(error)")
            }
        }

        throw URLError(.cannotFindHost)
    }

    private static func isLinkLocalReceiverURL(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return host.hasPrefix("fe80:")
    }
    
    private static func resolveEndpoint(_ endpoint: NWEndpoint) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(to: endpoint, using: .tcp)
            let lock = NSLock()
            final class ResumeState: @unchecked Sendable {
                var hasResumed = false
            }
            let resumeState = ResumeState()

            @Sendable func finish(_ result: Result<URL, Error>) {
                lock.lock()
                let shouldResume = !resumeState.hasResumed
                if shouldResume {
                    resumeState.hasResumed = true
                }
                lock.unlock()

                guard shouldResume else { return }

                connection.cancel()
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = innerEndpoint {
                        let hostStr: String
                        switch host {
                        case .ipv4(let addr):
                            hostStr = "\(addr)"
                        case .ipv6(let addr):
                            hostStr = "[\(addr)]"
                        default:
                            hostStr = "\(host)"
                        }
                        if let url = URL(string: "http://\(hostStr):\(port)") {
                            finish(.success(url))
                        } else {
                            finish(.failure(URLError(.badURL)))
                        }
                    } else {
                        finish(.failure(URLError(.cannotFindHost)))
                    }
                case .waiting(let error):
                    finish(.failure(error))
                case .failed(let error):
                    finish(.failure(error))
                case .cancelled:
                    finish(.failure(URLError(.cancelled)))
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))

            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                finish(.failure(URLError(.timedOut)))
            }
        }
    }
}

private func backupFailureReason(_ error: Error) -> String {
    let localizedDescription = error.localizedDescription
    if localizedDescription.contains("timed out") || localizedDescription.contains("시간 초과") {
        return "Mac 리시버와 연결할 수 없습니다. Mac의 iCherri 앱이 실행 중인지, 그리고 같은 Wi-Fi에 연결되어 있는지 확인해 주세요."
    }
    if localizedDescription.contains("Cannot find host") || localizedDescription.contains("Could not connect to the server") || localizedDescription.contains("호스트를 찾을 수") {
        return "백업 대상을 찾을 수 없습니다. 네트워크 설정을 확인해 주세요."
    }

    if let backupError = error as? BackupClientError {
        switch backupError {
        case .httpError(let statusCode, let data):
            let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let body, !body.isEmpty {
                return "HTTP \(statusCode): \(body)"
            }
            return "HTTP \(statusCode)."
        case .invalidResponse:
            return "Invalid server response."
        }
    }
    if let chunkError = error as? ChunkUploadError {
        switch chunkError {
        case .serverError(let statusCode):
            return "Chunk upload failed with HTTP \(statusCode)."
        case .streamError:
            return "Media stream could not be read."
        }
    }
    if let resumableError = error as? ResumableUploadError {
        switch resumableError {
        case .commitFailed(let status):
            return "Commit failed: \(status)."
        case .sessionExpired:
            return "Upload session expired."
        }
    }
    return localizedDescription
}

private actor BackupRunReconcileState {
    struct Counts: Sendable {
        let completed: Int
        let success: Int
        let duplicates: Int
        let failed: Int
        let overallBackedUpCount: Int
    }

    private let libraryAssetCount: Int
    private let runAssetCount: Int
    private let duplicateCount: Int
    private var uploadedAssetIDs: Set<String> = []
    private var failedAssetIDs: Set<String>
    private var receiverCompletedAssetCount: Int?

    init(libraryAssetCount: Int, runAssetCount: Int, duplicateCount: Int, failedAssetIDs: Set<String>) {
        self.libraryAssetCount = libraryAssetCount
        self.runAssetCount = runAssetCount
        self.duplicateCount = duplicateCount
        self.failedAssetIDs = failedAssetIDs
    }

    func recordSuccess(assetLocalID: String) -> Counts {
        uploadedAssetIDs.insert(assetLocalID)
        failedAssetIDs.remove(assetLocalID)
        return snapshotCounts()
    }

    func recordFailure(assetLocalID: String) -> Counts {
        failedAssetIDs.insert(assetLocalID)
        return snapshotCounts()
    }

    func setReceiverCompletedAssetCount(_ count: Int) {
        receiverCompletedAssetCount = count
    }

    func currentUploadedAssetIDs() -> Set<String> {
        uploadedAssetIDs
    }

    func snapshotCounts() -> Counts {
        let success = uploadedAssetIDs.count
        let failed = failedAssetIDs.count
        let receiverBackedUpCount = receiverCompletedAssetCount ?? 0
        let alreadyBackedUpCount = max(libraryAssetCount - runAssetCount, 0)
        let overallBackedUpCount = max(alreadyBackedUpCount + success + duplicateCount, receiverBackedUpCount)
        return Counts(
            completed: success + duplicateCount + failed,
            success: success,
            duplicates: duplicateCount,
            failed: failed,
            overallBackedUpCount: overallBackedUpCount
        )
    }
}

private actor BackupUploadProgressCoordinator {
    private struct ActiveUploadState {
        var filename: String
        var sentBytes: Int64 = 0
        var totalBytes: Int64 = 0
        var bytesPerSecond: Double = 0
    }

    private let viewModel: BackupProgressViewModel
    private let totalExpectedBytes: Int64
    private let totalCount: Int
    private let throttleIntervalNanoseconds: UInt64 = 150_000_000
    private var currentFilename: String = "Preparing uploads..."
    private var acknowledgedBytes: Int64 = 0
    private var completed: Int = 0
    private var success: Int = 0
    private var duplicates: Int = 0
    private var failed: Int = 0
    private var overallBackedUpCount: Int = 0
    private var activeUploads: [String: ActiveUploadState] = [:]
    private var failedUploads: [FailedUploadProgressItem] = []
    private var lastEmissionUptime: UInt64 = 0
    private var pendingEmissionTask: Task<Void, Never>?

    init(viewModel: BackupProgressViewModel, totalExpectedBytes: Int64, totalCount: Int) {
        self.viewModel = viewModel
        self.totalExpectedBytes = totalExpectedBytes
        self.totalCount = totalCount
    }

    func beginAsset(assetLocalID: String, filename: String, expectedByteSize: Int64) {
        currentFilename = filename
        activeUploads[assetLocalID] = ActiveUploadState(
            filename: filename,
            totalBytes: max(expectedByteSize, 0)
        )
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func updateSnapshot(
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        overallBackedUpCount: Int,
        phase: BackupProgressPhase,
        bytesPerSecond: Double
    ) {
        currentFilename = filename
        self.completed = completed
        self.success = success
        self.duplicates = duplicates
        self.failed = failed
        self.overallBackedUpCount = overallBackedUpCount
        pushUpdate(bytesPerSecond: bytesPerSecond, phase: phase, immediate: phase == .complete || phase == .failed)
    }

    func setInitialFailures(_ failures: [FailedUploadProgressItem]) {
        failedUploads = failures
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond, immediate: true)
    }

    func setAcknowledgedBytes(_ bytes: Int64) {
        acknowledgedBytes = max(bytes, 0)
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func didSendBytes(assetLocalID: String, filename: String, totalSent: Int64, totalExpected: Int64, bytesPerSecond: Double) {
        currentFilename = filename
        activeUploads[assetLocalID] = ActiveUploadState(
            filename: filename,
            sentBytes: totalSent,
            totalBytes: totalExpected,
            bytesPerSecond: bytesPerSecond
        )
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond)
    }

    func finishAsset(
        assetLocalID: String,
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        overallBackedUpCount: Int
    ) {
        currentFilename = filename
        if let state = activeUploads.removeValue(forKey: assetLocalID) {
            acknowledgedBytes += max(state.sentBytes, state.totalBytes)
        }
        self.completed = completed
        self.success = success
        self.duplicates = duplicates
        self.failed = failed
        self.overallBackedUpCount = overallBackedUpCount
        let phase: BackupProgressPhase = activeUploads.isEmpty && completed >= totalCount ? .complete : .uploading
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond, phase: phase, immediate: phase == .complete)
    }

    func recordFailure(assetLocalID: String, filename: String, reason: String) {
        failedUploads.removeAll { $0.id == assetLocalID || $0.id == "unsupported-\(assetLocalID)" }
        failedUploads.append(
            FailedUploadProgressItem(
                id: assetLocalID,
                filename: filename,
                reason: reason,
                retryAssetLocalID: assetLocalID
            )
        )
        failedUploads.sort { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        pushUpdate(bytesPerSecond: aggregateBytesPerSecond, phase: .failed, immediate: true)
    }

    private var aggregateBytesPerSecond: Double {
        activeUploads.values.reduce(0) { $0 + $1.bytesPerSecond }
    }

    private func pushUpdate(
        bytesPerSecond: Double,
        phase: BackupProgressPhase = .uploading,
        immediate: Bool = false
    ) {
        if immediate {
            pendingEmissionTask?.cancel()
            pendingEmissionTask = nil
            Task { await emitUpdate(bytesPerSecond: bytesPerSecond, phase: phase) }
            return
        }

        let isBackground = UIApplication.shared.applicationState == .background
        let currentThrottleInterval: UInt64 = isBackground ? 3_000_000_000 : 500_000_000

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now &- lastEmissionUptime
        if lastEmissionUptime == 0 || elapsed >= currentThrottleInterval {
            pendingEmissionTask?.cancel()
            pendingEmissionTask = nil
            Task { await emitUpdate(bytesPerSecond: bytesPerSecond, phase: phase) }
            return
        }

        guard !isBackground else { return }

        guard pendingEmissionTask == nil else { return }
        let remaining = currentThrottleInterval - elapsed
        pendingEmissionTask = Task { [self] in
            try? await Task.sleep(nanoseconds: remaining)
            await emitPendingUpdate()
        }
    }

    private func emitPendingUpdate() async {
        pendingEmissionTask = nil
        await emitUpdate(bytesPerSecond: aggregateBytesPerSecond, phase: .uploading)
    }

    private func emitUpdate(bytesPerSecond: Double, phase: BackupProgressPhase) async {
        lastEmissionUptime = DispatchTime.now().uptimeNanoseconds
        let activeBytesSent = activeUploads.values.reduce(Int64(0)) { $0 + $1.sentBytes }
        let activeBytesTotal = activeUploads.values.reduce(Int64(0)) { $0 + $1.totalBytes }
        let activeUploadItems = activeUploads
            .map { assetLocalID, state in
                ActiveUploadProgressItem(
                    id: assetLocalID,
                    assetLocalID: assetLocalID,
                    filename: state.filename,
                    sentBytes: state.sentBytes,
                    totalBytes: state.totalBytes,
                    bytesPerSecond: state.bytesPerSecond
                )
            }
            .sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }

        let snapshotFilename = currentFilename
        let snapshotCompleted = completed
        let snapshotSuccess = success
        let snapshotDuplicates = duplicates
        let snapshotFailed = failed
        let snapshotOverallBackedUpCount = overallBackedUpCount
        let snapshotSentBytes = acknowledgedBytes + activeBytesSent
        let snapshotTotalBytes = max(totalExpectedBytes, acknowledgedBytes + activeBytesTotal)
        let snapshotActiveCount = activeUploads.count
        let snapshotFailedUploads = failedUploads
        let snapshotViewModel = viewModel

        await MainActor.run {
            snapshotViewModel.update(
                filename: snapshotFilename,
                completed: snapshotCompleted,
                success: snapshotSuccess,
                duplicates: snapshotDuplicates,
                failed: snapshotFailed,
                overallBackedUpCount: snapshotOverallBackedUpCount,
                phase: phase,
                bytesPerSecond: bytesPerSecond,
                sentBytes: snapshotSentBytes,
                totalBytes: snapshotTotalBytes,
                activeUploads: snapshotActiveCount,
                activeUploadItems: activeUploadItems,
                failedUploadItems: snapshotFailedUploads
            )

            let formattedSpeed: String
            if bytesPerSecond > 0 {
                let mb = bytesPerSecond / (1024.0 * 1024.0)
                if mb >= 1.0 {
                    formattedSpeed = String(format: "%.1fM/s", mb)
                } else {
                    let kb = bytesPerSecond / 1024.0
                    formattedSpeed = String(format: "%.0fK/s", kb)
                }
            } else {
                formattedSpeed = "—"
            }

            let progressVal = totalCount > 0 ? Double(snapshotOverallBackedUpCount) / Double(totalCount) : 0.0

            if #available(iOS 16.2, *) {
                BackupLiveActivityManager.shared.update(
                    progress: progressVal,
                    completedCount: snapshotOverallBackedUpCount,
                    totalCount: totalCount,
                    formattedSpeed: formattedSpeed,
                    filename: snapshotFilename
                )
            }
        }
    }
}

private enum UploadTaskOutcome: Sendable {
    case success(assetLocalID: String, filename: String)
    case failure(assetLocalID: String, filename: String, reason: String)
}

private enum BackupRunReconcileError: LocalizedError {
    case unresolvedAssets([String])
    case exceededRetryRounds([String])

    var errorDescription: String? {
        switch self {
        case .unresolvedAssets(let assetIDs):
            return "Receiver requested assets without local metadata: \(assetIDs.joined(separator: ", "))."
        case .exceededRetryRounds(let assetIDs):
            return "Receiver still reports missing assets after reconcile retries: \(assetIDs.joined(separator: ", "))."
        }
    }
}

private actor AssetUploadProgressReporter: ChunkUploadProgressDelegate {
    private let assetLocalID: String
    private let filename: String
    private let coordinator: BackupUploadProgressCoordinator
    private var startedAt = Date()

    init(assetLocalID: String, filename: String, coordinator: BackupUploadProgressCoordinator) {
        self.assetLocalID = assetLocalID
        self.filename = filename
        self.coordinator = coordinator
    }

    func didSendBytes(_ bytes: Int64, totalSent: Int64, totalExpected: Int64) async {
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let bytesPerSecond = Double(totalSent) / elapsed
        await coordinator.didSendBytes(
            assetLocalID: assetLocalID,
            filename: filename,
            totalSent: totalSent,
            totalExpected: totalExpected,
            bytesPerSecond: bytesPerSecond
        )
    }
}

// MARK: - Live Activity / Dynamic Island Models

@available(iOS 16.2, *)
public struct BackupActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var completedCount: Int
        public var totalCount: Int
        public var formattedSpeed: String
        public var currentFilename: String?

        public init(
            progress: Double,
            completedCount: Int,
            totalCount: Int,
            formattedSpeed: String,
            currentFilename: String? = nil
        ) {
            self.progress = progress
            self.completedCount = completedCount
            self.totalCount = totalCount
            self.formattedSpeed = formattedSpeed
            self.currentFilename = currentFilename
        }
    }

    public let deviceName: String
    
    public init(deviceName: String) {
        self.deviceName = deviceName
    }
}

@available(iOS 16.2, *)
@MainActor
public final class BackupLiveActivityManager {
    public static let shared = BackupLiveActivityManager()
    private init() {}
    
    private var currentActivity: Activity<BackupActivityAttributes>?
    
    public func start(deviceName: String, completedCount: Int, totalCount: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are disabled by user or system.")
            return
        }
        
        stop()
        
        let attributes = BackupActivityAttributes(deviceName: deviceName)
        let initialState = BackupActivityAttributes.ContentState(
            progress: totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0,
            completedCount: completedCount,
            totalCount: totalCount,
            formattedSpeed: "—"
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
            print("[LiveActivity] Started Activity ID: \(activity.id)")
        } catch {
            print("[LiveActivity] Failed to request Activity: \(error)")
        }
    }
    
    public func update(progress: Double, completedCount: Int, totalCount: Int, formattedSpeed: String, filename: String?) {
        guard let activity = currentActivity else { return }
        
        let updatedState = BackupActivityAttributes.ContentState(
            progress: progress,
            completedCount: completedCount,
            totalCount: totalCount,
            formattedSpeed: formattedSpeed,
            currentFilename: filename
        )
        
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            print("[LiveActivity] Updated Activity: \(activity.id) (\(completedCount)/\(totalCount) - \(formattedSpeed))")
        }
    }
    
    public func stop() {
        guard let activity = currentActivity else { return }
        
        Task {
            let finalState = BackupActivityAttributes.ContentState(
                progress: 1.0,
                completedCount: activity.content.state.totalCount,
                totalCount: activity.content.state.totalCount,
                formattedSpeed: "Done"
            )
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(3.0)))
            self.currentActivity = nil
            print("[LiveActivity] Ended Activity: \(activity.id)")
        }
    }
}

