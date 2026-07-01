import SwiftUI
import Photos
import UIKit
import ICherriDesignSystem
import Inject

public enum BackupProgressPhase {
    case scanning
    case checking
    case uploading
    case complete
    case failed
}

// Animated real-time backup progress screen with speed, ETA, and per-asset status.
public struct BackupProgressView: View {
    @ObserveInjection var inject
    @ObservedObject var viewModel: BackupProgressViewModel

    public init(viewModel: BackupProgressViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            backgroundGradient
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if let autoBackupStatus = viewModel.autoBackupStatus {
                        autoBackupStatusSection(autoBackupStatus)
                    }
                    if let errorMessage = viewModel.errorMessage {
                        errorSection(errorMessage)
                    }
                    progressSection
                    statsSection
                    if !viewModel.activeUploads.isEmpty {
                        activeUploadsSection
                    }
                    if !viewModel.failedUploads.isEmpty {
                        failedUploadsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, viewModel.canCancel ? 120 : 32)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.canCancel {
                cancelBar
            }
        }
        .navigationBarBackButtonHidden(true)
        .enableInjection()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            if #available(iOS 17.0, *) {
                Image(systemName: viewModel.headerSymbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.headerSymbolColor)
                    .symbolEffect(.bounce, value: viewModel.currentFilename)
            } else {
                Image(systemName: viewModel.headerSymbolName)
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.headerSymbolColor)
            }

            Text(viewModel.headerTitle)
                .font(.system(.title2, design: .rounded, weight: .semibold))

        }
    }

    private func errorSection(_ errorMessage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func autoBackupStatusSection(_ status: AutoBackupStatusViewModel) -> some View {
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

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 10) {
            LiquidProgressBar(progress: viewModel.progress)
                .frame(height: 16)

            HStack {
                Text("\(viewModel.overallBackedUpCount) / \(viewModel.totalCount) backed up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(String(format: "%.0f%%", viewModel.progress * 100))
                    .font(.system(.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                
                Spacer()
                
                if let trailingStatus = viewModel.trailingStatusText {
                    Text(trailingStatus)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let transferStatus = viewModel.transferStatusText {
                HStack {
                    Text(transferStatus)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            GlowBadge(label: "This Run", value: "\(viewModel.sessionUploadedCount)", color: .green)
            GlowBadge(label: "Duration", value: viewModel.formattedDuration, color: .blue)
            GlowBadge(label: "Failed", value: "\(viewModel.failedCount)", color: .red)
        }
    }

    private var activeUploadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Uploads")
                    .font(.headline)
            }

            ForEach(viewModel.activeUploads) { upload in
                HStack(alignment: .top, spacing: 12) {
                    ActiveUploadThumbnailView(assetLocalID: upload.assetLocalID)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(upload.filename)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(upload.formattedSpeed)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: upload.progress)
                            .tint(.accentColor)

                        Text(upload.formattedTransfer)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var failedUploadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Failed Uploads")
                    .font(.headline)
                Spacer()
                if viewModel.canRetryFailedUploads {
                    Button("Retry Failed") {
                        viewModel.retryFailedUploads()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
                Text("\(viewModel.failedUploads.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.failedUploads) { failedUpload in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 12) {
                        Text(failedUpload.filename)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if failedUpload.isRetryable {
                            Button("Retry") {
                                viewModel.retryUpload(failedUpload)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                        }
                    }
                    Text(failedUpload.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Cancel

    private var cancelBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(role: .destructive) {
                viewModel.cancel()
            } label: {
                Text("Cancel Backup")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.accentColor.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - ViewModel

@MainActor
public final class BackupProgressViewModel: ObservableObject {
    @Published public var progress: Double = 0
    @Published public var completedCount: Int = 0
    @Published public var totalCount: Int = 0
    @Published public var successCount: Int = 0
    @Published public var duplicateCount: Int = 0
    @Published public var failedCount: Int = 0
    @Published public var overallBackedUpCount: Int = 0
    @Published public var currentFilename: String?
    @Published public var formattedSpeed: String = "—"
    @Published public var formattedTransfer: String = "—"
    @Published public var activeUploadCount: Int = 0
    @Published public var activeUploads: [ActiveUploadProgressItem] = []
    @Published public var failedUploads: [FailedUploadProgressItem] = []
    @Published public var isComplete: Bool = false
    @Published public var errorMessage: String?
    @Published public var phase: BackupProgressPhase = .scanning
    @Published var autoBackupStatus: AutoBackupStatusViewModel?

    @Published public var sessionTotalCount: Int = 0
    @Published public var elapsedTime: TimeInterval = 0
    private var durationTimer: Task<Void, Never>?

    public var formattedDuration: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    public func startDurationTimer() {
        durationTimer?.cancel()
        let startTime = Date()
        durationTimer = Task { @MainActor in
            while !Task.isCancelled {
                elapsedTime = Date().timeIntervalSince(startTime)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }

    public func stopDurationTimer() {
        durationTimer?.cancel()
        durationTimer = nil
    }

    public var onRetryFailedUploads: (([String]) -> Void)?
    public var onRetryUpload: ((String) -> Void)?

    private var sentBytes: Int64 = 0
    private var totalBytes: Int64 = 0

    private var cancellationToken: Task<Void, Never>?

    public init(totalCount: Int) {
        self.totalCount = totalCount
    }

    public func bindCancellation(to task: Task<Void, Never>) {
        cancellationToken = task
    }

    public func setTotalCount(_ count: Int) {
        sessionTotalCount = count
        progress = count > 0 ? Double(completedCount) / Double(count) : 0
        if completedCount < count {
            isComplete = false
        }
        formattedTransfer = formatTransfer(sentBytes: sentBytes, totalBytes: totalBytes)
    }

    public func setTotalBytes(_ bytes: Int64) {
        totalBytes = max(bytes, 0)
        formattedTransfer = formatTransfer(sentBytes: sentBytes, totalBytes: totalBytes)
    }

    public func setPhase(_ phase: BackupProgressPhase) {
        self.phase = phase
        switch phase {
        case .complete, .failed:
            isComplete = true
            stopDurationTimer()
        case .scanning:
            isComplete = false
            startDurationTimer()
        case .checking, .uploading:
            isComplete = false
        }
    }

    public func update(
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        overallBackedUpCount: Int? = nil,
        phase: BackupProgressPhase? = nil,
        bytesPerSecond: Double,
        sentBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        activeUploads: Int? = nil,
        activeUploadItems: [ActiveUploadProgressItem]? = nil,
        failedUploadItems: [FailedUploadProgressItem]? = nil
    ) {
        currentFilename = filename
        completedCount = completed
        successCount = success
        duplicateCount = duplicates
        failedCount = failed
        if let overallBackedUpCount {
            self.overallBackedUpCount = overallBackedUpCount
        }
        if let phase {
            self.phase = phase
            if phase == .complete || phase == .failed {
                stopDurationTimer()
            }
        }
        if let sentBytes {
            self.sentBytes = sentBytes
        }
        if let totalBytes {
            self.totalBytes = totalBytes
        }
        if let activeUploads {
            self.activeUploadCount = activeUploads
        }
        if let activeUploadItems {
            self.activeUploads = activeUploadItems
        }
        if let failedUploadItems {
            failedUploads = failedUploadItems
        }

        progress = sessionTotalCount > 0 ? Double(completed) / Double(sessionTotalCount) : 0
        formattedSpeed = formatSpeed(bytesPerSecond)
        formattedTransfer = formatTransfer(sentBytes: self.sentBytes, totalBytes: self.totalBytes)
        if sessionTotalCount > 0, completed >= sessionTotalCount {
            isComplete = true
            stopDurationTimer()
        } else if phase != .failed && phase != .complete {
            isComplete = false
        }
    }

    public func markRunFailed(_ message: String) {
        errorMessage = message
        isComplete = true
        formattedSpeed = "—"
        phase = .failed
        stopDurationTimer()
    }

    func setAutoBackupStatus(_ status: AutoBackupStatusViewModel?) {
        autoBackupStatus = status
    }

    public var canCancel: Bool {
        !isComplete && errorMessage == nil
    }

    public var sessionUploadedCount: Int {
        successCount
    }

    public var canRetryFailedUploads: Bool {
        failedUploads.contains(where: \.isRetryable)
    }

    public var headerTitle: String {
        if errorMessage != nil { return "Backup Failed" }
        if isComplete { return "Backup Complete" }
        switch phase {
        case .scanning:
            return "Scanning Library…"
        case .checking:
            return "Checking Backups…"
        case .uploading:
            return "Backing Up…"
        case .complete:
            return "Backup Complete"
        case .failed:
            return "Backup Failed"
        }
    }

    public var headerSymbolName: String {
        if errorMessage != nil { return "exclamationmark.triangle.fill" }
        if isComplete { return "checkmark.circle.fill" }
        switch phase {
        case .scanning:
            return "photo.stack"
        case .checking:
            return "checklist"
        case .uploading:
            return "arrow.up.to.line.compact"
        case .complete:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    public var headerSymbolColor: Color {
        if errorMessage != nil { return .red }
        if isComplete { return .green }
        return .accentColor
    }

    public var trailingStatusText: String? {
        switch phase {
        case .scanning:
            return "Scanning"
        case .checking:
            return "Checking"
        case .uploading:
            return formattedSpeed
        case .complete:
            return "Done"
        case .failed:
            return "Failed"
        }
    }

    public var transferStatusText: String? {
        switch phase {
        case .uploading, .complete:
            return formattedTransfer
        case .scanning:
            return totalBytes > 0 ? "Library size \(formatByteCount(totalBytes))" : "Calculating library size..."
        case .checking:
            return "Comparing with Mac..."
        case .failed:
            return formattedTransfer == "—" ? nil : formattedTransfer
        }
    }

    public func cancel() {
        cancellationToken?.cancel()
    }

    public func retryFailedUploads() {
        let assetIDs = failedUploads.compactMap(\.retryAssetLocalID)
        guard !assetIDs.isEmpty else { return }
        onRetryFailedUploads?(assetIDs)
    }

    public func retryUpload(_ failedUpload: FailedUploadProgressItem) {
        guard let assetLocalID = failedUpload.retryAssetLocalID else { return }
        onRetryUpload?(assetLocalID)
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f KB/s", bps / 1_000) }
        return String(format: "%.0f B/s", bps)
    }

    private func formatTransfer(sentBytes: Int64, totalBytes: Int64) -> String {
        guard totalBytes > 0 else { return "0 B / —" }

        let sent = formatByteCount(sentBytes)
        let total = formatByteCount(totalBytes)
        return "\(sent) / \(total)"
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        if bytes < 1_000 {
            return "\(bytes) B"
        }
        if bytes < 1_000_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        if bytes < 1_000_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        return String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }
}

public struct ActiveUploadProgressItem: Identifiable, Equatable {
    public let id: String
    public let assetLocalID: String
    public let filename: String
    public let sentBytes: Int64
    public let totalBytes: Int64
    public let bytesPerSecond: Double

    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(Double(sentBytes) / Double(totalBytes), 1)
    }

    public var formattedTransfer: String {
        guard totalBytes > 0 else { return "0 B / —" }
        let sent = formatByteCount(sentBytes)
        let total = formatByteCount(totalBytes)
        return "\(sent) / \(total)"
    }

    public var formattedSpeed: String {
        if bytesPerSecond >= 1_000_000 { return String(format: "%.1f MB/s", bytesPerSecond / 1_000_000) }
        if bytesPerSecond >= 1_000 { return String(format: "%.0f KB/s", bytesPerSecond / 1_000) }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    private func formatByteCount(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        if bytes < 1_000 {
            return "\(bytes) B"
        }
        if bytes < 1_000_000 {
            return String(format: "%.1f KB", Double(bytes) / 1_000)
        }
        if bytes < 1_000_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000)
        }
        return String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }
}

public struct FailedUploadProgressItem: Identifiable, Equatable {
    public let id: String
    public let filename: String
    public let reason: String
    public let retryAssetLocalID: String?

    public var isRetryable: Bool {
        retryAssetLocalID != nil
    }
}

struct ActiveUploadThumbnailView: View {
    let assetLocalID: String
    @StateObject private var loader: AssetThumbnailLoader

    init(assetLocalID: String) {
        self.assetLocalID = assetLocalID
        _loader = StateObject(wrappedValue: AssetThumbnailLoader(assetLocalID: assetLocalID))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task {
            await loader.loadIfNeeded()
        }
    }
}

@MainActor
final class AssetThumbnailLoader: ObservableObject {
    @Published var image: UIImage?

    private let assetLocalID: String
    private var hasLoaded = false

    init(assetLocalID: String) {
        self.assetLocalID = assetLocalID
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalID], options: nil)
        guard let asset = result.firstObject else { return }

        let targetSize = CGSize(width: 104, height: 104)
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                self?.image = image
                continuation.resume()
            }
        }
    }
}
