import Foundation
import GRDB
import ICherriCore

// MARK: - Database Records

struct PairedDeviceRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "paired_devices"

    var id: Int64?
    var deviceId: String
    var deviceName: String
    var pairingStatus: String
    var createdAt: Date
    var lastSeenAt: Date
    var trustToken: String

    enum Columns: String, ColumnExpression {
        case id, deviceId = "device_id", deviceName = "device_name"
        case pairingStatus = "pairing_status", createdAt = "created_at"
        case lastSeenAt = "last_seen_at", trustToken = "trust_token"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case deviceName = "device_name"
        case pairingStatus = "pairing_status"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case trustToken = "trust_token"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct BackupAssetRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "backup_assets"

    var id: Int64?
    var backupId: String
    var deviceId: String
    var assetLocalId: String
    var originalFilename: String
    var mediaType: String
    var creationDate: Date
    var modificationDate: Date
    var byteSize: Int64
    var durationSeconds: Double?
    var pixelWidth: Int
    var pixelHeight: Int
    var quickFingerprint: String
    var contentSha256: String
    var finalPath: String
    var status: String
    var duplicateOfBackupId: String?
    var firstSeenAt: Date
    var completedAt: Date?
    var lastError: String?

    enum Columns: String, ColumnExpression {
        case id, backupId = "backup_id", deviceId = "device_id"
        case assetLocalId = "asset_local_id", originalFilename = "original_filename"
        case mediaType = "media_type", creationDate = "creation_date"
        case modificationDate = "modification_date", byteSize = "byte_size"
        case durationSeconds = "duration_seconds", pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height", quickFingerprint = "quick_fingerprint"
        case contentSha256 = "content_sha256", finalPath = "final_path"
        case status, duplicateOfBackupId = "duplicate_of_backup_id"
        case firstSeenAt = "first_seen_at", completedAt = "completed_at"
        case lastError = "last_error"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case backupId = "backup_id"
        case deviceId = "device_id"
        case assetLocalId = "asset_local_id"
        case originalFilename = "original_filename"
        case mediaType = "media_type"
        case creationDate = "creation_date"
        case modificationDate = "modification_date"
        case byteSize = "byte_size"
        case durationSeconds = "duration_seconds"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case quickFingerprint = "quick_fingerprint"
        case contentSha256 = "content_sha256"
        case finalPath = "final_path"
        case status
        case duplicateOfBackupId = "duplicate_of_backup_id"
        case firstSeenAt = "first_seen_at"
        case completedAt = "completed_at"
        case lastError = "last_error"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct UploadSessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "upload_sessions"

    var uploadId: String
    var deviceId: String
    var assetLocalId: String
    var tempPath: String
    var expectedByteSize: Int64
    var receivedBytes: Int64
    var chunkSize: Int
    var status: String
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date
    var metadataJson: String
    var lastError: String?

    enum Columns: String, ColumnExpression {
        case uploadId = "upload_id", deviceId = "device_id"
        case assetLocalId = "asset_local_id", tempPath = "temp_path"
        case expectedByteSize = "expected_byte_size", receivedBytes = "received_bytes"
        case chunkSize = "chunk_size", status, createdAt = "created_at"
        case updatedAt = "updated_at", expiresAt = "expires_at", metadataJson = "metadata_json", lastError = "last_error"
    }

    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case deviceId = "device_id"
        case assetLocalId = "asset_local_id"
        case tempPath = "temp_path"
        case expectedByteSize = "expected_byte_size"
        case receivedBytes = "received_bytes"
        case chunkSize = "chunk_size"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
        case metadataJson = "metadata_json"
        case lastError = "last_error"
    }
}

struct UploadFailureLogRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "upload_failure_logs"

    var id: Int64?
    var uploadId: String
    var deviceId: String
    var assetLocalId: String
    var status: String
    var errorCode: String
    var errorMessage: String
    var receivedBytes: Int64
    var expectedByteSize: Int64
    var createdAt: Date
    var metadataJson: String

    enum Columns: String, ColumnExpression {
        case id
        case uploadId = "upload_id"
        case deviceId = "device_id"
        case assetLocalId = "asset_local_id"
        case status
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case receivedBytes = "received_bytes"
        case expectedByteSize = "expected_byte_size"
        case createdAt = "created_at"
        case metadataJson = "metadata_json"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case uploadId = "upload_id"
        case deviceId = "device_id"
        case assetLocalId = "asset_local_id"
        case status
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case receivedBytes = "received_bytes"
        case expectedByteSize = "expected_byte_size"
        case createdAt = "created_at"
        case metadataJson = "metadata_json"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Database Manager

actor DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    private init() {}

    func open(at path: String) throws {
        var config = Configuration()
        config.label = "iCherri-DB"
        let queue = try DatabaseQueue(path: path, configuration: config)
        try migrate(queue)
        dbQueue = queue
    }

    private var queue: DatabaseQueue {
        get throws {
            guard let q = dbQueue else { throw DatabaseError.notOpen }
            return q
        }
    }

    // MARK: Migrations

    private func migrate(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "paired_devices") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("device_id", .text).notNull().unique()
                t.column("device_name", .text).notNull()
                t.column("pairing_status", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("last_seen_at", .datetime).notNull()
                t.column("trust_token", .text).notNull()
            }

            try db.create(table: "backup_assets") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("backup_id", .text).notNull().unique()
                t.column("device_id", .text).notNull().references("paired_devices", column: "device_id")
                t.column("asset_local_id", .text).notNull()
                t.column("original_filename", .text).notNull()
                t.column("media_type", .text).notNull()
                t.column("creation_date", .datetime).notNull()
                t.column("modification_date", .datetime).notNull()
                t.column("byte_size", .integer).notNull()
                t.column("duration_seconds", .double)
                t.column("pixel_width", .integer).notNull()
                t.column("pixel_height", .integer).notNull()
                t.column("quick_fingerprint", .text).notNull()
                t.column("content_sha256", .text).notNull()
                t.column("final_path", .text).notNull()
                t.column("status", .text).notNull()
                t.column("duplicate_of_backup_id", .text)
                t.column("first_seen_at", .datetime).notNull()
                t.column("completed_at", .datetime)
                t.column("last_error", .text)
                t.uniqueKey(["device_id", "asset_local_id"])
            }

            try db.create(index: "idx_backup_assets_fingerprint", on: "backup_assets", columns: ["quick_fingerprint"])
            try db.create(index: "idx_backup_assets_sha256", on: "backup_assets", columns: ["content_sha256"])

            try db.create(table: "upload_sessions") { t in
                t.column("upload_id", .text).primaryKey()
                t.column("device_id", .text).notNull()
                t.column("asset_local_id", .text).notNull()
                t.column("temp_path", .text).notNull()
                t.column("expected_byte_size", .integer).notNull()
                t.column("received_bytes", .integer).notNull()
                t.column("chunk_size", .integer).notNull()
                t.column("status", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("expires_at", .datetime).notNull()
                t.column("metadata_json", .text).notNull()
                t.column("last_error", .text)
            }
        }

        migrator.registerMigration("v2_upload_failure_logs") { db in
            try db.create(table: "upload_failure_logs") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("upload_id", .text).notNull()
                t.column("device_id", .text).notNull()
                t.column("asset_local_id", .text).notNull()
                t.column("status", .text).notNull()
                t.column("error_code", .text).notNull()
                t.column("error_message", .text).notNull()
                t.column("received_bytes", .integer).notNull()
                t.column("expected_byte_size", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("metadata_json", .text).notNull()
            }

            try db.create(index: "idx_upload_failure_logs_created_at", on: "upload_failure_logs", columns: ["created_at"])
        }

        try migrator.migrate(queue)
    }

    // MARK: - Paired Devices

    func upsertDevice(_ record: PairedDeviceRecord) throws {
        try queue.write { db in
            try record.save(db)
        }
    }

    func fetchDevice(id deviceId: String) throws -> PairedDeviceRecord? {
        try queue.read { db in
            try PairedDeviceRecord.filter(Column("device_id") == deviceId).fetchOne(db)
        }
    }

    func updateLastSeen(deviceId: String) throws {
        try queue.write { db in
            try db.execute(
                sql: "UPDATE paired_devices SET last_seen_at = ? WHERE device_id = ?",
                arguments: [Date(), deviceId]
            )
        }
    }

    // MARK: - Backup Assets

    func insertBackupAsset(_ record: BackupAssetRecord) throws {
        try queue.write { db in
            try record.insert(db)
        }
    }

    func fetchAsset(deviceId: String, assetLocalId: String) throws -> BackupAssetRecord? {
        try queue.read { db in
            try BackupAssetRecord
                .filter(Column("device_id") == deviceId && Column("asset_local_id") == assetLocalId)
                .fetchOne(db)
        }
    }

    func fetchAsset(fingerprint: String) throws -> BackupAssetRecord? {
        try queue.read { db in
            try BackupAssetRecord
                .filter(Column("quick_fingerprint") == fingerprint && Column("status") == "completed")
                .fetchOne(db)
        }
    }

    func fetchAsset(sha256: String) throws -> BackupAssetRecord? {
        try queue.read { db in
            try BackupAssetRecord
                .filter(Column("content_sha256") == sha256 && Column("status") == "completed")
                .fetchOne(db)
        }
    }

    func markAssetDuplicate(assetLocalId: String, deviceId: String, duplicateOfBackupId: String) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                UPDATE backup_assets
                SET status = 'duplicate', duplicate_of_backup_id = ?
                WHERE asset_local_id = ? AND device_id = ?
                """,
                arguments: [duplicateOfBackupId, assetLocalId, deviceId]
            )
        }
    }

    // Inserts a logical duplicate record without storing a physical file.
    func insertDuplicateAsset(
        deviceId: String,
        assetLocalId: String,
        originalFilename: String,
        mediaType: String,
        creationDate: Date,
        modificationDate: Date,
        byteSize: Int64,
        pixelWidth: Int,
        pixelHeight: Int,
        quickFingerprint: String,
        duplicateOfBackupId: String
    ) throws {
        let record = BackupAssetRecord(
            id: nil,
            backupId: UUID().uuidString,
            deviceId: deviceId,
            assetLocalId: assetLocalId,
            originalFilename: originalFilename,
            mediaType: mediaType,
            creationDate: creationDate,
            modificationDate: modificationDate,
            byteSize: byteSize,
            durationSeconds: nil,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            quickFingerprint: quickFingerprint,
            contentSha256: "",
            finalPath: "",
            status: "duplicate",
            duplicateOfBackupId: duplicateOfBackupId,
            firstSeenAt: Date(),
            completedAt: Date(),
            lastError: nil
        )
        try queue.write { db in
            try record.insert(db)
        }
    }

    // MARK: - Upload Sessions

    func insertUploadSession(_ record: UploadSessionRecord) throws {
        try queue.write { db in
            try record.insert(db)
        }
    }

    func fetchUploadSession(uploadId: String) throws -> UploadSessionRecord? {
        try queue.read { db in
            try UploadSessionRecord.fetchOne(db, key: uploadId)
        }
    }

    func fetchActiveUploadSession(deviceId: String, assetLocalId: String, expectedByteSize: Int64) throws -> UploadSessionRecord? {
        try queue.read { db in
            try UploadSessionRecord
                .filter(Column("device_id") == deviceId)
                .filter(Column("asset_local_id") == assetLocalId)
                .filter(Column("expected_byte_size") == expectedByteSize)
                .filter(
                    sql: "status IN (?, ?, ?)",
                    arguments: ["initialized", "receiving", "paused"]
                )
                .order(Column("updated_at").desc)
                .fetchOne(db)
        }
    }

    func insertUploadFailureLog(_ record: UploadFailureLogRecord) throws {
        try queue.write { db in
            try record.insert(db)
        }
    }

    func updateUploadProgress(uploadId: String, receivedBytes: Int64, status: String) throws {
        let extended = Date().addingTimeInterval(24 * 3600)
        try queue.write { db in
            try db.execute(
                sql: """
                UPDATE upload_sessions
                SET received_bytes = ?, status = ?, updated_at = ?, expires_at = ?
                WHERE upload_id = ?
                """,
                arguments: [receivedBytes, status, Date(), extended, uploadId]
            )
        }
    }

    func deleteUploadSession(uploadId: String) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM upload_sessions WHERE upload_id = ?", arguments: [uploadId])
        }
    }

    func fetchExpiredSessions() throws -> [UploadSessionRecord] {
        try queue.read { db in
            try UploadSessionRecord
                .filter(Column("expires_at") < Date())
                .fetchAll(db)
        }
    }

    // MARK: - Dashboard Query Helpers

    func fetchAllDevices() throws -> [PairedDeviceRecord] {
        try queue.read { db in
            try PairedDeviceRecord.order(Column("last_seen_at").desc).fetchAll(db)
        }
    }

    func fetchAllAssets() throws -> [BackupAssetRecord] {
        try queue.read { db in
            try BackupAssetRecord.order(Column("completed_at").desc).fetchAll(db)
        }
    }

    func fetchAssets(
        deviceId: String,
        searchQuery: String,
        status: String?,
        limit: Int,
        offset: Int
    ) throws -> [BackupAssetRecord] {
        try queue.read { db in
            var request = BackupAssetRecord
                .filter(Column("device_id") == deviceId)

            if let status {
                request = request.filter(Column("status") == status)
            }

            let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedQuery.isEmpty {
                let pattern = "%\(trimmedQuery)%"
                request = request.filter(
                    sql: "original_filename LIKE ? COLLATE NOCASE OR asset_local_id LIKE ? COLLATE NOCASE",
                    arguments: [pattern, pattern]
                )
            }

            return try request
                .order(sql: "COALESCE(completed_at, first_seen_at) DESC")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    func fetchAllSessions() throws -> [UploadSessionRecord] {
        try queue.read { db in
            try UploadSessionRecord
                .filter(
                    sql: "status IN (?, ?, ?)",
                    arguments: ["initialized", "receiving", "paused"]
                )
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    func deletePairedDevice(deviceId: String) throws -> [String] {
        try queue.write { db in
            let tempPaths = try String.fetchAll(
                db,
                sql: "SELECT temp_path FROM upload_sessions WHERE device_id = ?",
                arguments: [deviceId]
            )

            try db.execute(sql: "DELETE FROM upload_sessions WHERE device_id = ?", arguments: [deviceId])
            try db.execute(sql: "DELETE FROM upload_failure_logs WHERE device_id = ?", arguments: [deviceId])
            try db.execute(sql: "DELETE FROM backup_assets WHERE device_id = ?", arguments: [deviceId])
            try db.execute(sql: "DELETE FROM paired_devices WHERE device_id = ?", arguments: [deviceId])

            return tempPaths
        }
    }
}

// MARK: - Errors

enum DatabaseError: Error {
    case notOpen
}

extension DatabaseManager: BackupIndexQuerying {
    public func findByDeviceAndAssetID(deviceID: String, assetLocalID: String) async throws -> BackupIndexEntry? {
        if let record = try await fetchAsset(deviceId: deviceID, assetLocalId: assetLocalID) {
            return BackupIndexEntry(backupID: record.backupId, status: record.status, contentSHA256: record.contentSha256)
        }
        return nil
    }

    public func findByFingerprint(_ fingerprint: String) async throws -> BackupIndexEntry? {
        if let record = try await fetchAsset(fingerprint: fingerprint) {
            return BackupIndexEntry(backupID: record.backupId, status: record.status, contentSHA256: record.contentSha256)
        }
        return nil
    }

    public func findBySHA256(_ sha256: String) async throws -> BackupIndexEntry? {
        if let record = try await fetchAsset(sha256: sha256) {
            return BackupIndexEntry(backupID: record.backupId, status: record.status, contentSHA256: record.contentSha256)
        }
        return nil
    }
}
