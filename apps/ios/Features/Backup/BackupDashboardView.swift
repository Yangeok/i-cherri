import SwiftUI
import Network
import ICherriProtocol
import ICherriDesignSystem
import Inject

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
                        pairingSection
                        if viewModel.isPaired {
                            backupTriggerSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("iCherri")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            Task { await viewModel.refreshReceivers() }
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
                            Text(receiverName)
                                .font(.subheadline.weight(.semibold))
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
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Looking for Mac receivers…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.discoveredReceivers) { receiver in
                        receiverRow(receiver)
                    }
                }
                if let message = viewModel.pairingStatusMessage {
                    Label(message, systemImage: viewModel.isPaired ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(viewModel.isPaired ? .green : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                if let receiverName = viewModel.pairedReceiverName {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected to \(receiverName)")
                                .font(.subheadline)
                            Spacer()
                        }

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
                    }
                }
                Button(action: { Task { await viewModel.startBackup() } }) {
                    Label("Start Backup", systemImage: "arrow.up.to.line.compact")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBackingUp)
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
    @Published var activeBackupProgressViewModel: BackupProgressViewModel?
    @Published var backupCoverageSummary: String?
    @Published var backupCoverageProgress: Double?

    private let scanner = PhotoLibraryScanner()
    private let scanIndexStore = PhotoLibraryScanIndexStore.shared
    private let bonjourBrowser = BonjourBrowser()
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
        updatePhotoPermission()
        restorePairingState()
        scanIndexStore.startObserving()
        bonjourBrowser.startBrowsing()
        // Observe browser changes
        Task { @MainActor in
            for await receivers in bonjourBrowser.$discoveredReceivers.values {
                self.discoveredReceivers = receivers
                self.localNetworkStatus = receivers.isEmpty ? self.localNetworkStatus : .granted
                if let pairedReceiverID = UserDefaults.standard.string(forKey: self.receiverIDKey) {
                    self.pairedReceiver = receivers.first(where: { $0.id == pairedReceiverID })
                } else if let pairedReceiverName {
                    self.pairedReceiver = receivers.first(where: { $0.name == pairedReceiverName })
                }
            }
        }
        Task { @MainActor in
            for await status in bonjourBrowser.$status.values {
                switch status {
                case .ready:
                    self.localNetworkStatus = .granted
                case .failed:
                    self.localNetworkStatus = .denied
                case .idle, .browsing:
                    if self.localNetworkStatus != .granted {
                        self.localNetworkStatus = .unknown
                    }
                }
            }
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
            
            let url = baseURL.appendingPathComponent("/pair")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
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
        backupCoverageSummary = nil
        backupCoverageProgress = nil
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

        let backupTask = Task.detached(priority: .userInitiated) { [maxConcurrentUploads = Self.maxConcurrentUploads] in
            var executedScanMode: PhotoLibraryScanPlan.Mode = .incremental
            defer {
                Task { @MainActor in
                    self.isBackingUp = false
                }
            }

            do {
                try Task.checkCancellation()

                let scanPlan = await self.scanIndexStore.makeScanPlan(scanner: self.scanner, deviceID: device.deviceID)
                executedScanMode = scanPlan.mode
                let scannedAssets = scanPlan.assets

                await MainActor.run {
                    progressViewModel.setTotalCount(scanPlan.totalAssetCount)
                    progressViewModel.setTotalBytes(scanPlan.totalAssetBytes)
                }

                try Task.checkCancellation()

                if scannedAssets.isEmpty {
                    await MainActor.run {
                        progressViewModel.update(
                            filename: scanPlan.mode == .incremental ? "Nothing new to back up" : "No media found",
                            completed: scanPlan.totalAssetCount,
                            success: 0,
                            duplicates: 0,
                            failed: 0,
                            overallBackedUpCount: scanPlan.totalAssetCount,
                            phase: .complete,
                            bytesPerSecond: 0,
                            totalBytes: scanPlan.totalAssetBytes
                        )
                        self.updateBackupCoverage(backedUpCount: 0, totalCount: scanPlan.totalAssetCount)
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
                        totalExpectedBytes: scanPlan.totalAssetBytes,
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
                let batchResponse = try await backupClient.checkBatch(
                    candidates: scannedAssets,
                    totalAssetCount: scanPlan.totalAssetCount,
                    totalAssetBytes: scanPlan.totalAssetBytes
                )
                let assetIndex = Dictionary(uniqueKeysWithValues: scannedAssets.map { ($0.assetLocalID, $0) })

                var completed = batchResponse.alreadyBackedUp.count + batchResponse.duplicates.count + batchResponse.unsupported.count
                var success = 0
                let duplicates = batchResponse.alreadyBackedUp.count + batchResponse.duplicates.count
                var failed = batchResponse.unsupported.count
                var pendingAssets: [AssetMetadata] = []
                let duplicateBytes = (batchResponse.alreadyBackedUp + batchResponse.duplicates)
                    .compactMap { assetIndex[$0]?.byteSize }
                    .reduce(Int64(0), +)
                await MainActor.run {
                    self.updateBackupCoverage(backedUpCount: duplicates, totalCount: scanPlan.totalAssetCount)
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
                        failed += 1
                        completed += 1
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
                    pendingAssets.append(metadata)
                }

                let requiredUploadIDs = pendingAssets.map(\.assetLocalID)
                await MainActor.run {
                    self.scanIndexStore.markRetryRequired(assetIDs: requiredUploadIDs)
                }

                await progressCoordinator.setInitialFailures(initialFailures)
                await progressCoordinator.setAcknowledgedBytes(duplicateBytes)
                await progressCoordinator.updateSnapshot(
                    filename: "Preparing uploads...",
                    completed: completed,
                    success: success,
                    duplicates: duplicates,
                    failed: failed,
                    overallBackedUpCount: duplicates,
                    phase: pendingAssets.isEmpty ? .complete : .uploading,
                    bytesPerSecond: 0
                )

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

                        switch outcome {
                        case .success(let assetLocalID, let filename):
                            success += 1
                            completed += 1
                            let overallBackedUpCount = duplicates + success
                            await MainActor.run {
                                self.updateBackupCoverage(backedUpCount: overallBackedUpCount, totalCount: scanPlan.totalAssetCount)
                                self.scanIndexStore.markSucceeded(assetIDs: [assetLocalID])
                            }
                            await progressCoordinator.finishAsset(
                                assetLocalID: assetLocalID,
                                filename: filename,
                                completed: completed,
                                success: success,
                                duplicates: duplicates,
                                failed: failed,
                                overallBackedUpCount: overallBackedUpCount
                            )
                        case .failure(let assetLocalID, let filename, let reason):
                            failed += 1
                            completed += 1
                            await progressCoordinator.finishAsset(
                                assetLocalID: assetLocalID,
                                filename: filename,
                                completed: completed,
                                success: success,
                                duplicates: duplicates,
                                failed: failed,
                                overallBackedUpCount: duplicates + success
                            )
                            await progressCoordinator.recordFailure(
                                assetLocalID: assetLocalID,
                                filename: filename,
                                reason: reason
                            )
                        }

                        let desiredConcurrency = UploadConcurrencyPolicy.recommendedConcurrency(
                            for: pendingAssets[nextIndex...],
                            maxAllowed: maxConcurrentUploads
                        )
                        while activeTaskCount < desiredConcurrency && nextIndex < pendingAssets.count {
                            enqueueNextUpload()
                        }
                    }
                }

                let finalSuccess = success
                let finalDuplicates = duplicates
                let finalFailed = failed
                await MainActor.run {
                    self.updateBackupCoverage(backedUpCount: finalDuplicates + finalSuccess, totalCount: scanPlan.totalAssetCount)
                    self.scanIndexStore.finishBackupRun(mode: scanPlan.mode)
                    self.backupStatusMessage = "Backup complete. Uploaded \(finalSuccess), skipped \(finalDuplicates), failed \(finalFailed)."
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
    }

    private func describeBackupError(_ error: Error) -> String {
        backupFailureReason(error)
    }
    
    private func currentDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            deviceID: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            deviceName: UIDevice.current.name,
            platform: "iOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
    }

    private static func resolveReceiverURLForBackup(
        pairedReceiver: DiscoveredReceiver?,
        pairedReceiverID: String?,
        pairedReceiverName: String?,
        discoveredReceivers: [DiscoveredReceiver],
        storedReceiverURLString: String?
    ) async throws -> URL {
        if let pairedReceiver {
            return try await resolveEndpoint(pairedReceiver.endpoint)
        }

        if let pairedReceiverID,
           let discoveredReceiver = discoveredReceivers.first(where: { $0.id == pairedReceiverID }) {
            return try await resolveEndpoint(discoveredReceiver.endpoint)
        }

        if let pairedReceiverName,
           let discoveredReceiver = discoveredReceivers.first(where: { $0.name == pairedReceiverName }) {
            return try await resolveEndpoint(discoveredReceiver.endpoint)
        }

        if let storedReceiverURLString,
           let receiverURL = URL(string: storedReceiverURLString),
           !isLinkLocalReceiverURL(receiverURL) {
            return receiverURL
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
            var hasResumed = false

            func finish(_ result: Result<URL, Error>) {
                lock.lock()
                let shouldResume = !hasResumed
                if shouldResume {
                    hasResumed = true
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
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                finish(.failure(URLError(.timedOut)))
            }
        }
    }
}

private func backupFailureReason(_ error: Error) -> String {
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
    return error.localizedDescription
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

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now &- lastEmissionUptime
        if lastEmissionUptime == 0 || elapsed >= throttleIntervalNanoseconds {
            Task { await emitUpdate(bytesPerSecond: bytesPerSecond, phase: phase) }
            return
        }

        guard pendingEmissionTask == nil else { return }
        let remaining = throttleIntervalNanoseconds - elapsed
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
        }
    }
}

private enum UploadTaskOutcome: Sendable {
    case success(assetLocalID: String, filename: String)
    case failure(assetLocalID: String, filename: String, reason: String)
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
