import Foundation

public struct ProtocolVersion: Codable, Sendable, Equatable {
    public let major: Int
    public let minor: Int

    public static let current = ProtocolVersion(major: 1, minor: 0)

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
}

public struct DeviceInfo: Codable, Sendable {
    public let deviceID: String
    public let deviceName: String
    public let platform: String
    public let appVersion: String
    public let protocolVersion: ProtocolVersion

    public init(
        deviceID: String,
        deviceName: String,
        platform: String,
        appVersion: String,
        protocolVersion: ProtocolVersion = .current
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.platform = platform
        self.appVersion = appVersion
        self.protocolVersion = protocolVersion
    }
}

public enum MediaType: String, Codable, Sendable {
    case photo
    case video
    case livePhotoComponent = "live_photo_component"
    case unknown
}

public struct AssetMetadata: Codable, Sendable {
    public let deviceID: String
    public let assetLocalID: String
    public let originalFilename: String
    public let mediaType: MediaType
    public let creationDate: Date
    public let modificationDate: Date
    public let byteSize: Int64
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let quickFingerprint: String
    public let durationSeconds: Double?

    public init(
        deviceID: String,
        assetLocalID: String,
        originalFilename: String,
        mediaType: MediaType,
        creationDate: Date,
        modificationDate: Date,
        byteSize: Int64,
        pixelWidth: Int,
        pixelHeight: Int,
        quickFingerprint: String,
        durationSeconds: Double? = nil
    ) {
        self.deviceID = deviceID
        self.assetLocalID = assetLocalID
        self.originalFilename = originalFilename
        self.mediaType = mediaType
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.byteSize = byteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.quickFingerprint = quickFingerprint
        self.durationSeconds = durationSeconds
    }
}

public struct ReceiverInfo: Codable, Sendable {
    public let receiverID: String
    public let receiverName: String
    public let platform: String
    public let appVersion: String
    public let protocolVersion: ProtocolVersion
    public let status: String
    public let availableFeatures: [String]

    public init(
        receiverID: String,
        receiverName: String,
        platform: String,
        appVersion: String,
        protocolVersion: ProtocolVersion = .current,
        status: String = "running",
        availableFeatures: [String] = ["resumable_upload", "metadata_dedupe"]
    ) {
        self.receiverID = receiverID
        self.receiverName = receiverName
        self.platform = platform
        self.appVersion = appVersion
        self.protocolVersion = protocolVersion
        self.status = status
        self.availableFeatures = availableFeatures
    }
}

public enum AutoBackupRunState: String, Codable, Sendable {
    case scheduled
    case eligibilityBlocked = "eligibility_blocked"
    case preparing
    case uploading
    case paused
    case partial
    case completed
    case expired
}

public enum RunPauseReason: String, Codable, Sendable {
    case receiverUnavailable = "receiver_unavailable"
    case receiverChanged = "receiver_changed"
    case thermal
    case appSuspended = "app_suspended"
    case manualCancel = "manual_cancel"
}

public enum AutoBackupAssetState: String, Codable, Sendable {
    case queued
    case staged
    case uploading
    case committed
    case skippedDuplicate = "skipped_duplicate"
    case failedRetained = "failed_retained"
}

public enum StagedFileUsageState: String, Codable, Sendable {
    case ready
    case uploading
    case committed
    case cleanupEligible = "cleanup_eligible"
}

public enum ReceiverUploadSessionState: String, Codable, Sendable {
    case initialized
    case receiving
    case paused
    case committed
    case expired
}

public enum AutoBackupThermalThreshold: String, Codable, Sendable {
    case serious
    case critical
}

public struct AutoBackupPolicy: Codable, Sendable, Equatable {
    public let isEnabled: Bool
    public let minimumBatteryPercent: Int
    public let requiresWiFiEnabled: Bool
    public let blocksOnLowPowerMode: Bool
    public let pauseThermalThreshold: AutoBackupThermalThreshold
    public let stagedStorageLimitBytes: Int64

    public init(
        isEnabled: Bool = false,
        minimumBatteryPercent: Int = 20,
        requiresWiFiEnabled: Bool = true,
        blocksOnLowPowerMode: Bool = false,
        pauseThermalThreshold: AutoBackupThermalThreshold = .serious,
        stagedStorageLimitBytes: Int64 = 2_147_483_648
    ) {
        self.isEnabled = isEnabled
        self.minimumBatteryPercent = minimumBatteryPercent
        self.requiresWiFiEnabled = requiresWiFiEnabled
        self.blocksOnLowPowerMode = blocksOnLowPowerMode
        self.pauseThermalThreshold = pauseThermalThreshold
        self.stagedStorageLimitBytes = stagedStorageLimitBytes
    }
}

public struct AutoBackupRunContext: Codable, Sendable, Equatable {
    public let backupRunID: String
    public let receiverID: String
    public let clientSessionID: String?

    public init(backupRunID: String, receiverID: String, clientSessionID: String? = nil) {
        self.backupRunID = backupRunID
        self.receiverID = receiverID
        self.clientSessionID = clientSessionID
    }
}
