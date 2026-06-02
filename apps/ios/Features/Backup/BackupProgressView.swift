import SwiftUI
import ICherriDesignSystem
import Inject

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
            VStack(spacing: 32) {
                headerSection
                progressSection
                statsSection
                Spacer()
                cancelButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
        .navigationBarBackButtonHidden(true)
        .enableInjection()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            if #available(iOS 17.0, *) {
                Image(systemName: viewModel.isComplete ? "checkmark.circle.fill" : "arrow.up.to.line.compact")
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.isComplete ? .green : .accentColor)
                    .symbolEffect(.bounce, value: viewModel.currentFilename)
            } else {
                Image(systemName: viewModel.isComplete ? "checkmark.circle.fill" : "arrow.up.to.line.compact")
                    .font(.system(size: 48))
                    .foregroundStyle(viewModel.isComplete ? .green : .accentColor)
            }

            Text(viewModel.isComplete ? "Backup Complete" : "Backing Up…")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            if !viewModel.isComplete, let filename = viewModel.currentFilename {
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.3), value: filename)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 10) {
            LiquidProgressBar(progress: viewModel.progress)
                .frame(height: 16)

            HStack {
                Text("\(viewModel.completedCount) / \(viewModel.totalCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.formattedSpeed)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(viewModel.formattedTransfer)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.activeUploadCount > 0 {
                    Text("\(viewModel.activeUploadCount) active")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            GlowBadge(label: "Uploaded", value: "\(viewModel.successCount)", color: .green)
            GlowBadge(label: "Skipped", value: "\(viewModel.duplicateCount)", color: .orange)
            GlowBadge(label: "Failed", value: "\(viewModel.failedCount)", color: .red)
        }
    }

    // MARK: - Cancel

    private var cancelButton: some View {
        Group {
            if !viewModel.isComplete {
                Button(role: .destructive) {
                    viewModel.cancel()
                } label: {
                    Text("Cancel Backup")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
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
    @Published public var currentFilename: String?
    @Published public var formattedSpeed: String = "—"
    @Published public var formattedTransfer: String = "—"
    @Published public var activeUploadCount: Int = 0
    @Published public var isComplete: Bool = false

    private var sentBytes: Int64 = 0
    private var totalBytes: Int64 = 0

    private var cancellationToken: Task<Void, Never>?

    public init(totalCount: Int) {
        self.totalCount = totalCount
    }

    public func bindCancellation(to task: Task<Void, Never>) {
        cancellationToken = task
    }

    public func update(
        filename: String,
        completed: Int,
        success: Int,
        duplicates: Int,
        failed: Int,
        bytesPerSecond: Double,
        sentBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        activeUploads: Int? = nil
    ) {
        currentFilename = filename
        completedCount = completed
        successCount = success
        duplicateCount = duplicates
        failedCount = failed
        if let sentBytes {
            self.sentBytes = sentBytes
        }
        if let totalBytes {
            self.totalBytes = totalBytes
        }
        if let activeUploads {
            self.activeUploadCount = activeUploads
        }

        if self.totalBytes > 0 {
            progress = min(Double(self.sentBytes) / Double(self.totalBytes), 1)
        } else {
            progress = totalCount > 0 ? Double(completed) / Double(totalCount) : 0
        }
        formattedSpeed = formatSpeed(bytesPerSecond)
        formattedTransfer = formatTransfer(sentBytes: self.sentBytes, totalBytes: self.totalBytes)
        if completed >= totalCount { isComplete = true }
    }

    public func cancel() {
        cancellationToken?.cancel()
    }

    private func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f KB/s", bps / 1_000) }
        return String(format: "%.0f B/s", bps)
    }

    private func formatTransfer(sentBytes: Int64, totalBytes: Int64) -> String {
        guard totalBytes > 0 else { return "Waiting for first transfer…" }

        let sent = ByteCountFormatter.string(fromByteCount: sentBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(sent) / \(total)"
    }
}
