import Foundation

// MARK: - Pairing

public struct PairingStartRequest: Codable, Sendable {
    public let deviceID: String
    public let deviceName: String
    public let platform: String
    public let appVersion: String
    public let protocolVersion: ProtocolVersion

    public init(device: DeviceInfo) {
        self.deviceID = device.deviceID
        self.deviceName = device.deviceName
        self.platform = device.platform
        self.appVersion = device.appVersion
        self.protocolVersion = device.protocolVersion
    }
}

public struct PairingStartResponse: Codable, Sendable {
    public let status: String
    public let expiresAt: Date

    public init(status: String, expiresAt: Date) {
        self.status = status
        self.expiresAt = expiresAt
    }
}

public struct PairingConfirmRequest: Codable, Sendable {
    public let deviceID: String
    public let pinCode: String

    public init(deviceID: String, pinCode: String) {
        self.deviceID = deviceID
        self.pinCode = pinCode
    }
}

public struct PairingConfirmResponse: Codable, Sendable {
    public let status: String
    public let trustToken: String

    public init(status: String, trustToken: String) {
        self.status = status
        self.trustToken = trustToken
    }
}

// MARK: - Check Batch

public struct CheckBatchLibrarySnapshot: Codable, Sendable {
    public let totalAssetCount: Int
    public let totalAssetBytes: Int64

    public init(totalAssetCount: Int, totalAssetBytes: Int64) {
        self.totalAssetCount = totalAssetCount
        self.totalAssetBytes = totalAssetBytes
    }
}

public struct CheckBatchRequest: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let device: DeviceInfo
    public let candidates: [AssetMetadata]
    public let librarySnapshot: CheckBatchLibrarySnapshot?

    public init(
        device: DeviceInfo,
        candidates: [AssetMetadata],
        librarySnapshot: CheckBatchLibrarySnapshot? = nil
    ) {
        self.protocolVersion = .current
        self.device = device
        self.candidates = candidates
        self.librarySnapshot = librarySnapshot
    }
}

public enum UploadReason: String, Codable, Sendable {
    case notFound
    case metadataChanged
}

public struct UploadRequirement: Codable, Sendable {
    public let assetLocalID: String
    public let uploadReason: UploadReason
    public let uploadMode: String
    public let preferredChunkSize: Int

    public static let defaultChunkSize = 5 * 1024 * 1024  // 5 MB

    public init(assetLocalID: String, uploadReason: UploadReason, preferredChunkSize: Int = defaultChunkSize) {
        self.assetLocalID = assetLocalID
        self.uploadReason = uploadReason
        self.uploadMode = "resumableHTTPChunked"
        self.preferredChunkSize = preferredChunkSize
    }
}

public struct CheckBatchResponse: Codable, Sendable {
    public let requiredUploads: [UploadRequirement]
    public let alreadyBackedUp: [String]
    public let duplicates: [String]
    public let unsupported: [String]

    public init(
        requiredUploads: [UploadRequirement],
        alreadyBackedUp: [String] = [],
        duplicates: [String] = [],
        unsupported: [String] = []
    ) {
        self.requiredUploads = requiredUploads
        self.alreadyBackedUp = alreadyBackedUp
        self.duplicates = duplicates
        self.unsupported = unsupported
    }
}

// MARK: - Upload Init

public struct UploadAssetRef: Codable, Sendable {
    public let assetLocalID: String
    public let byteSize: Int64

    public init(assetLocalID: String, byteSize: Int64) {
        self.assetLocalID = assetLocalID
        self.byteSize = byteSize
    }
}

public struct UploadInitRequest: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let device: DeviceInfo
    public let asset: AssetMetadata
    public let filename: String
    public let expectedByteSize: Int64
    public let requestedChunkSize: Int

    public init(device: DeviceInfo, asset: AssetMetadata, filename: String, requestedChunkSize: Int = UploadRequirement.defaultChunkSize) {
        self.protocolVersion = .current
        self.device = device
        self.asset = asset
        self.filename = filename
        self.expectedByteSize = asset.byteSize
        self.requestedChunkSize = requestedChunkSize
    }
}

public struct UploadInitResponse: Codable, Sendable {
    public let uploadID: String
    public let accepted: Bool
    public let chunkSize: Int
    public let receivedBytes: Int64
    public let expiresAt: Date

    public init(uploadID: String, accepted: Bool, chunkSize: Int, receivedBytes: Int64 = 0, expiresAt: Date) {
        self.uploadID = uploadID
        self.accepted = accepted
        self.chunkSize = chunkSize
        self.receivedBytes = receivedBytes
        self.expiresAt = expiresAt
    }
}

// MARK: - Chunk Upload

public struct ChunkUploadResponse: Codable, Sendable {
    public let uploadID: String
    public let index: Int
    public let receivedBytes: Int64
    public let status: String

    public init(uploadID: String, index: Int, receivedBytes: Int64, status: String = "receiving") {
        self.uploadID = uploadID
        self.index = index
        self.receivedBytes = receivedBytes
        self.status = status
    }
}

// MARK: - Upload Status

public struct UploadStatusResponse: Codable, Sendable {
    public let uploadID: String
    public let status: String
    public let receivedBytes: Int64
    public let expiresAt: Date

    public init(uploadID: String, status: String, receivedBytes: Int64, expiresAt: Date) {
        self.uploadID = uploadID
        self.status = status
        self.receivedBytes = receivedBytes
        self.expiresAt = expiresAt
    }
}

// MARK: - Commit Upload

public struct CommitUploadRequest: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let uploadID: String
    public let assetLocalID: String
    public let finalByteSize: Int64
    public let finalContentHash: String
    public let clientFinishedAt: Date

    public init(uploadID: String, assetLocalID: String, finalByteSize: Int64, finalContentHash: String) {
        self.protocolVersion = .current
        self.uploadID = uploadID
        self.assetLocalID = assetLocalID
        self.finalByteSize = finalByteSize
        self.finalContentHash = finalContentHash
        self.clientFinishedAt = Date()
    }
}

public struct CommitUploadResponse: Codable, Sendable {
    public let status: String
    public let backupID: String?
    public let displayPath: String?
    public let errorMessage: String?

    public static func success(backupID: String, displayPath: String) -> CommitUploadResponse {
        CommitUploadResponse(status: "completed", backupID: backupID, displayPath: displayPath, errorMessage: nil)
    }

    public static func failure(status: String, message: String) -> CommitUploadResponse {
        CommitUploadResponse(status: status, backupID: nil, displayPath: nil, errorMessage: message)
    }

    private init(status: String, backupID: String?, displayPath: String?, errorMessage: String?) {
        self.status = status
        self.backupID = backupID
        self.displayPath = displayPath
        self.errorMessage = errorMessage
    }
}

// MARK: - Error Response

public struct APIError: Codable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
