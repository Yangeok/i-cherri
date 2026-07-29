import Foundation
import ICherriProtocol

struct AutoBackupStatusViewModel: Equatable, Sendable {
    let title: String
    let detail: String
    let symbolName: String

    static func make(
        isEnabled: Bool,
        receiverName: String?,
        activeRun: AutoBackupRun?,
        fallbackMessage: String?,
        latestEvent: BackupEventRecord?
    ) -> AutoBackupStatusViewModel {
        guard isEnabled else {
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Is Off",
                detail: "Turn it on to schedule photo and video backups.",
                symbolName: "bolt.slash.circle"
            )
        }

        guard let activeRun else {
            return AutoBackupStatusViewModel(
                title: receiverName == nil ? "Waiting For Backup Target" : "Automatic Backup Is Ready",
                detail: fallbackMessage ?? (receiverName == nil
                    ? "Choose a Mac receiver before automatic backup can start."
                    : "The next eligible check will prepare changed assets."),
                symbolName: receiverName == nil ? "desktopcomputer.trianglebadge.exclamationmark" : "clock.badge.checkmark"
            )
        }

        let detail = latestEvent?.message ?? detailText(for: activeRun, fallbackMessage: fallbackMessage)

        switch activeRun.state {
        case .scheduled:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Is Scheduled",
                detail: detail,
                symbolName: "clock.badge.checkmark"
            )
        case .eligibilityBlocked:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Is Waiting",
                detail: detail,
                symbolName: "pause.circle"
            )
        case .preparing:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Is Preparing",
                detail: detail,
                symbolName: "tray.and.arrow.down"
            )
        case .uploading:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Is Uploading",
                detail: detail,
                symbolName: "arrow.up.circle"
            )
        case .paused:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Is Paused",
                detail: detail,
                symbolName: "pause.circle.fill"
            )
        case .partial:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Needs Another Pass",
                detail: detail,
                symbolName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
            )
        case .completed:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Completed",
                detail: detail,
                symbolName: "checkmark.circle.fill"
            )
        case .expired:
            return AutoBackupStatusViewModel(
                title: "Automatic Backup Expired",
                detail: detail,
                symbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90"
            )
        }
    }

    static func recentResultText(for run: AutoBackupRun?) -> String? {
        guard let run else { return nil }

        let committedCount = run.assetRecords.filter { $0.state == .committed }.count
        let duplicateCount = run.assetRecords.filter { $0.state == .skippedDuplicate }.count
        let failedCount = run.assetRecords.filter { $0.state == .failedRetained }.count

        switch run.state {
        case .completed:
            return "Last result: uploaded \(committedCount), skipped \(duplicateCount)."
        case .partial:
            return "Last result: uploaded \(committedCount), skipped \(duplicateCount), retrying \(failedCount)."
        case .expired:
            return "Last result: prepared run expired before finishing."
        default:
            return nil
        }
    }

    static func lastSuccessText(for run: AutoBackupRun?, now: Date = Date()) -> String? {
        guard let run, run.assetRecords.contains(where: { $0.state == .committed }) else { return nil }
        return "Last success \(relativeString(from: run.updatedAt, now: now))."
    }

    static func nextEvaluationText(for date: Date?, now: Date = Date()) -> String? {
        guard let date else { return nil }
        return date <= now
            ? "Next automatic check is ready now."
            : "Next automatic check \(relativeString(from: date, now: now))."
    }

    private static func detailText(for run: AutoBackupRun, fallbackMessage: String?) -> String {
        if let lastError = run.lastError, !lastError.isEmpty {
            if lastError == "staged_limit_exceeded" {
                return "Automatic backup paused because staged uploads reached the 2 GB limit."
            }
            return lastError
        }

        if let pauseReason = run.pauseReason {
            switch pauseReason {
            case .receiverUnavailable:
                return "Waiting for the paired Mac receiver to come back online."
            case .receiverChanged:
                return "The backup target changed. The new Mac will start a fresh run."
            case .thermal:
                return "Paused until iPhone temperature drops."
            case .appSuspended:
                return "Waiting for the next background wake to resume."
            case .manualCancel:
                return "Paused because the current run was cancelled."
            }
        }

        switch run.state {
        case .scheduled:
            return fallbackMessage ?? "The next eligible check will prepare changed assets."
        case .eligibilityBlocked:
            return fallbackMessage ?? "Waiting for battery, Wi-Fi, and receiver conditions."
        case .preparing:
            return "Building the next upload queue from changed assets."
        case .uploading:
            return "Only unfinished assets continue from this run."
        case .paused:
            return fallbackMessage ?? "The run is paused until conditions recover."
        case .partial:
            return "Some assets still need another automatic pass."
        case .completed:
            return "Changed assets finished without needing a manual rerun."
        case .expired:
            return "The saved run aged out after seven days."
        }
    }

    private static func relativeString(from date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
