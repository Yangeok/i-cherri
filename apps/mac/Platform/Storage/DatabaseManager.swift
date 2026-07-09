import Foundation
import AVFoundation
import GRDB
import ICherriCore
import ICherriProtocol

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
    var backupRunId: String?
    var clientSessionId: String?
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
        case assetLocalId = "asset_local_id", backupRunId = "backup_run_id", clientSessionId = "client_session_id"
        case tempPath = "temp_path"
        case expectedByteSize = "expected_byte_size", receivedBytes = "received_bytes"
        case chunkSize = "chunk_size", status, createdAt = "created_at"
        case updatedAt = "updated_at", expiresAt = "expires_at", metadataJson = "metadata_json", lastError = "last_error"
    }

    enum CodingKeys: String, CodingKey {
        case uploadId = "upload_id"
        case deviceId = "device_id"
        case assetLocalId = "asset_local_id"
        case backupRunId = "backup_run_id"
        case clientSessionId = "client_session_id"
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

struct BackupRunRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "backup_runs"

    var runId: String
    var deviceId: String
    var totalAssetCount: Int
    var totalAssetBytes: Int64
    var status: String
    var createdAt: Date
    var updatedAt: Date
    var finalizedAt: Date?

    enum Columns: String, ColumnExpression {
        case runId = "run_id", deviceId = "device_id"
        case totalAssetCount = "total_asset_count", totalAssetBytes = "total_asset_bytes"
        case status, createdAt = "created_at", updatedAt = "updated_at"
        case finalizedAt = "finalized_at"
    }
}

struct BackupRunAssetRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "backup_run_assets"

    var runId: String
    var deviceId: String
    var assetLocalId: String
    var quickFingerprint: String
    var byteSize: Int64
    var metadataJson: String
    var createdAt: Date

    enum Columns: String, ColumnExpression {
        case runId = "run_id", deviceId = "device_id"
        case assetLocalId = "asset_local_id", quickFingerprint = "quick_fingerprint", byteSize = "byte_size"
        case metadataJson = "metadata_json", createdAt = "created_at"
    }
}

struct BackupRunReconcileSnapshot: Sendable {
    let status: String
    let totalAssetCount: Int
    let completedAssetCount: Int
    let missingAssetIDs: [String]
}

struct BackupRunCoverageSummary: Sendable {
    let runId: String
    let deviceId: String
    let totalAssetCount: Int
    let completedAssetCount: Int
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let finalizedAt: Date?

    var pendingAssetCount: Int {
        max(totalAssetCount - completedAssetCount, 0)
    }
}

// MARK: - Database Manager

actor DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private var pendingInserts: [BackupAssetRecord] = []
    private var insertWaiters: [CheckedContinuation<Void, any Error>] = []
    private var isFlushing = false

    #if DEBUG
    init() {}
    #else
    private init() {}
    #endif

    func open(at path: String) throws {
        var config = Configuration()
        config.label = "iCherri-DB"
        config.journalMode = .wal // Enable Write-Ahead Logging
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

        migrator.registerMigration("v4_upload_session_context") { db in
            try db.alter(table: "upload_sessions") { t in
                t.add(column: "backup_run_id", .text)
                t.add(column: "client_session_id", .text)
            }

            try db.create(
                index: "idx_upload_sessions_context",
                on: "upload_sessions",
                columns: ["device_id", "asset_local_id", "backup_run_id", "client_session_id"]
            )
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

        migrator.registerMigration("v3_backup_run_snapshots") { db in
            try db.create(table: "backup_runs") { t in
                t.column("run_id", .text).primaryKey()
                t.column("device_id", .text).notNull().references("paired_devices", column: "device_id")
                t.column("total_asset_count", .integer).notNull()
                t.column("total_asset_bytes", .integer).notNull()
                t.column("status", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("finalized_at", .datetime)
            }

            try db.create(table: "backup_run_assets") { t in
                t.column("run_id", .text).notNull().references("backup_runs", column: "run_id", onDelete: .cascade)
                t.column("device_id", .text).notNull()
                t.column("asset_local_id", .text).notNull()
                t.column("quick_fingerprint", .text).notNull()
                t.column("byte_size", .integer).notNull()
                t.column("metadata_json", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.primaryKey(["run_id", "asset_local_id"])
            }

            try db.create(index: "idx_backup_run_assets_device_asset", on: "backup_run_assets", columns: ["device_id", "asset_local_id"])
            try db.create(index: "idx_backup_run_assets_fingerprint", on: "backup_run_assets", columns: ["quick_fingerprint"])
        }

        try migrator.migrate(queue)
    }

    // MARK: - Paired Devices

    func upsertDevice(_ record: PairedDeviceRecord) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO paired_devices
                    (device_id, device_name, pairing_status, created_at, last_seen_at, trust_token)
                VALUES
                    (?, ?, ?, ?, ?, ?)
                ON CONFLICT(device_id) DO UPDATE SET
                    device_name = excluded.device_name,
                    pairing_status = excluded.pairing_status,
                    last_seen_at = excluded.last_seen_at,
                    trust_token = excluded.trust_token
                """,
                arguments: [
                    record.deviceId,
                    record.deviceName,
                    record.pairingStatus,
                    record.createdAt,
                    record.lastSeenAt,
                    record.trustToken
                ]
            )
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

    func insertBackupAsset(_ record: BackupAssetRecord) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            pendingInserts.append(record)
            insertWaiters.append(continuation)

            if !isFlushing {
                isFlushing = true
                Task {
                    await flushInserts()
                }
            }
        }
    }

    private func flushInserts() {
        let records = pendingInserts
        let waiters = insertWaiters
        pendingInserts.removeAll()
        insertWaiters.removeAll()
        isFlushing = false

        guard !records.isEmpty else { return }

        do {
            let q = try queue
            try q.write { db in
                for record in records {
                    try record.insert(db)
                }
            }
            for waiter in waiters {
                waiter.resume()
            }
        } catch {
            for waiter in waiters {
                waiter.resume(throwing: error)
            }
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

    // MARK: - Backup Runs

    /// Mac DB 기준 특정 디바이스의 완료+중복 파일 총 수 반환 — iOS SSOT 동기화에 사용
    func fetchCompletedAssetCount(deviceID: String) throws -> Int {
        try queue.read { db in
            let count = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM backup_assets
                WHERE device_id = ?
                  AND status IN ('completed', 'duplicate')
                """,
                arguments: [deviceID]
            )
            return count ?? 0
        }
    }

    func replaceBackupRunSnapshot(
        runID: String,
        device: DeviceInfo,
        librarySnapshot: CheckBatchLibrarySnapshot?,
        candidates: [AssetMetadata]
    ) throws {
        let now = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO backup_runs
                    (run_id, device_id, total_asset_count, total_asset_bytes, status, created_at, updated_at, finalized_at)
                VALUES
                    (?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(run_id) DO UPDATE SET
                    total_asset_count = excluded.total_asset_count,
                    total_asset_bytes = excluded.total_asset_bytes,
                    status = excluded.status,
                    updated_at = excluded.updated_at,
                    finalized_at = NULL
                """,
                arguments: [
                    runID,
                    device.deviceID,
                    librarySnapshot?.totalAssetCount ?? candidates.count,
                    librarySnapshot?.totalAssetBytes ?? candidates.reduce(Int64(0)) { partial, asset in
                        partial + max(asset.byteSize, 0)
                    },
                    "snapshot_recorded",
                    now,
                    now
                ]
            )

            try db.execute(sql: "DELETE FROM backup_run_assets WHERE run_id = ?", arguments: [runID])

            for candidate in candidates {
                let metadataData = try encoder.encode(candidate)
                guard let metadataJSON = String(data: metadataData, encoding: .utf8) else {
                    throw DatabaseError.invalidMetadataEncoding
                }

                try db.execute(
                    sql: """
                    INSERT INTO backup_run_assets
                        (run_id, device_id, asset_local_id, quick_fingerprint, byte_size, metadata_json, created_at)
                    VALUES
                        (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        runID,
                        device.deviceID,
                        candidate.assetLocalID,
                        candidate.quickFingerprint,
                        max(candidate.byteSize, 0),
                        metadataJSON,
                        now
                    ]
                )
            }
        }
    }

    func finalizeBackupRun(runID: String, deviceID: String) throws -> BackupRunReconcileSnapshot {
        try queue.write { db in
            let missingAssetIDs = try String.fetchAll(
                db,
                sql: """
                SELECT s.asset_local_id
                FROM backup_run_assets AS s
                WHERE s.run_id = ?
                  AND s.device_id = ?
                  AND NOT EXISTS (
                      SELECT 1
                      FROM backup_assets AS b
                      WHERE b.status IN ('completed', 'duplicate')
                        AND (
                            (b.device_id = s.device_id AND b.asset_local_id = s.asset_local_id)
                            OR b.quick_fingerprint = s.quick_fingerprint
                        )
                  )
                ORDER BY s.created_at DESC, s.asset_local_id DESC
                """,
                arguments: [runID, deviceID]
            )

            let totalAssetCount = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM backup_run_assets
                WHERE run_id = ? AND device_id = ?
                """,
                arguments: [runID, deviceID]
            ) ?? 0

            let completedAssetCount = max(totalAssetCount - missingAssetIDs.count, 0)
            let status: String
            if missingAssetIDs.isEmpty {
                status = "complete"
            } else if completedAssetCount > 0 {
                status = "partial"
            } else {
                status = "needs_uploads"
            }
            try db.execute(
                sql: """
                UPDATE backup_runs
                SET status = ?, updated_at = ?, finalized_at = ?
                WHERE run_id = ? AND device_id = ?
                """,
                arguments: [
                    status,
                    Date(),
                    Date(),
                    runID,
                    deviceID
                ]
            )

            return BackupRunReconcileSnapshot(
                status: status,
                totalAssetCount: totalAssetCount,
                completedAssetCount: completedAssetCount,
                missingAssetIDs: missingAssetIDs
            )
        }
    }

    func fetchLatestBackupCoverageSummaries() throws -> [BackupRunCoverageSummary] {
        try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    r.run_id,
                    r.device_id,
                    r.total_asset_count,
                    r.status,
                    r.created_at,
                    r.updated_at,
                    r.finalized_at,
                    (
                        SELECT COUNT(*)
                        FROM backup_assets AS b
                        WHERE b.device_id = r.device_id
                          AND b.status IN ('completed', 'duplicate')
                    ) AS completed_asset_count
                FROM backup_runs AS r
                WHERE r.run_id = (
                    SELECT r2.run_id
                    FROM backup_runs AS r2
                    WHERE r2.device_id = r.device_id
                    ORDER BY r2.created_at DESC, r2.updated_at DESC, r2.run_id DESC
                    LIMIT 1
                )
                """
            )

            return rows.map { row in
                BackupRunCoverageSummary(
                    runId: row["run_id"],
                    deviceId: row["device_id"],
                    totalAssetCount: row["total_asset_count"],
                    completedAssetCount: row["completed_asset_count"] ?? 0,
                    status: row["status"],
                    createdAt: row["created_at"],
                    updatedAt: row["updated_at"],
                    finalizedAt: row["finalized_at"]
                )
            }
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

    func fetchActiveUploadSession(
        deviceId: String,
        assetLocalId: String,
        expectedByteSize: Int64,
        backupRunId: String? = nil,
        clientSessionId: String? = nil
    ) throws -> UploadSessionRecord? {
        try queue.read { db in
            var request = UploadSessionRecord
                .filter(Column("device_id") == deviceId)
                .filter(Column("asset_local_id") == assetLocalId)
                .filter(Column("expected_byte_size") == expectedByteSize)
                .filter(
                    sql: "status IN (?, ?, ?)",
                    arguments: ["initialized", "receiving", "paused"]
                )

            if let backupRunId {
                request = request.filter(Column("backup_run_id") == backupRunId)
            }

            if let clientSessionId {
                request = request.filter(Column("client_session_id") == clientSessionId)
            }

            return try request
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

    func fetchCoveredBytesByDevice(deviceIDs: [String]) throws -> [String: Int64] {
        guard !deviceIDs.isEmpty else { return [:] }

        return try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT device_id, COALESCE(SUM(byte_size), 0) AS covered_bytes
                FROM backup_assets
                WHERE device_id IN \(deviceIDs)
                  AND status IN ('completed', 'duplicate')
                GROUP BY device_id
                """
            )

            var result: [String: Int64] = [:]
            result.reserveCapacity(deviceIDs.count)
            for row in rows {
                let deviceID: String = row["device_id"]
                let coveredBytes: Int64 = row["covered_bytes"]
                result[deviceID] = coveredBytes
            }
            return result
        }
    }

    func fetchAssets(
        deviceId: String,
        searchQuery: String,
        status: String?,
        mediaType: String?,
        limit: Int,
        offset: Int
    ) throws -> [BackupAssetRecord] {
        try queue.read { db in
            var request = BackupAssetRecord
                .filter(Column("device_id") == deviceId)

            if let status {
                request = request.filter(Column("status") == status)
            }

            if let mediaType {
                request = request.filter(Column("media_type") == mediaType)
            }

            let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedQuery.isEmpty {
                let pattern = "%\(trimmedQuery)%"
                request = request.filter(
                    sql: "original_filename LIKE ? COLLATE NOCASE",
                    arguments: [pattern]
                )
            }

            return try request
                .order(sql: "creation_date DESC, COALESCE(completed_at, first_seen_at) DESC")
                .limit(limit, offset: offset)
                .fetchAll(db)
        }
    }

    func fetchAllSessions() throws -> [UploadSessionRecord] {
        try queue.read { db in
            try UploadSessionRecord
                .filter(
                    sql: "((status = ? OR status = ?) AND updated_at >= ?)",
                    arguments: ["receiving", "initialized", Date().addingTimeInterval(-120)]
                )
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    struct DeviceBackupStats: Codable {
        let completedCount: Int
        let duplicateCount: Int
        let failedCount: Int
        let lastBackupDate: Date?
    }

    func fetchBackupStatsByDevice() throws -> [String: DeviceBackupStats] {
        try queue.read { db in
            var result: [String: DeviceBackupStats] = [:]
            let rows = try Row.fetchAll(db, sql: """
                SELECT 
                    device_id,
                    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
                    SUM(CASE WHEN status = 'duplicate' THEN 1 ELSE 0 END) as duplicate_count,
                    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
                    MAX(completed_at) as last_backup
                FROM backup_assets
                GROUP BY device_id
            """)
            
            for row in rows {
                let deviceID: String = row["device_id"]
                let completed: Int = row["completed_count"] ?? 0
                let duplicate: Int = row["duplicate_count"] ?? 0
                let failed: Int = row["failed_count"] ?? 0
                let lastBackup: Date? = row["last_backup"]
                
                result[deviceID] = DeviceBackupStats(
                    completedCount: completed,
                    duplicateCount: duplicate,
                    failedCount: failed,
                    lastBackupDate: lastBackup
                )
            }
            return result
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
    case invalidMetadataEncoding
}

extension DatabaseManager: BackupIndexQuerying {
    public func findByDeviceAndAssetID(deviceID: String, assetLocalID: String) async throws -> BackupIndexEntry? {
        if let record = try fetchAsset(deviceId: deviceID, assetLocalId: assetLocalID) {
            return BackupIndexEntry(backupID: record.backupId, status: record.status, contentSHA256: record.contentSha256)
        }
        return nil
    }

    public func findByFingerprint(_ fingerprint: String) async throws -> BackupIndexEntry? {
        if let record = try fetchAsset(fingerprint: fingerprint) {
            return BackupIndexEntry(backupID: record.backupId, status: record.status, contentSHA256: record.contentSha256)
        }
        return nil
    }

    public func findByCandidate(_ candidate: AssetMetadata) async throws -> BackupIndexEntry? {
        try await findByFingerprint(candidate.quickFingerprint)
    }

    public func findBySHA256(_ sha256: String) async throws -> BackupIndexEntry? {
        if let record = try fetchAsset(sha256: sha256) {
            return BackupIndexEntry(backupID: record.backupId, status: record.status, contentSHA256: record.contentSha256)
        }
        return nil
    }

    public func registerDuplicate(candidate: AssetMetadata, duplicateOfBackupID: String) async throws {
        if let _ = try fetchAsset(deviceId: candidate.deviceID, assetLocalId: candidate.assetLocalID) {
            return
        }
        try insertDuplicateAsset(
            deviceId: candidate.deviceID,
            assetLocalId: candidate.assetLocalID,
            originalFilename: candidate.originalFilename,
            mediaType: candidate.mediaType.rawValue,
            creationDate: candidate.creationDate,
            modificationDate: candidate.modificationDate,
            byteSize: candidate.byteSize,
            pixelWidth: candidate.pixelWidth,
            pixelHeight: candidate.pixelHeight,
            quickFingerprint: candidate.quickFingerprint,
            duplicateOfBackupId: duplicateOfBackupID
        )
    }

    // MARK: - Duration Patch

    /// duration_seconds 가 NULL인 video 레코드를 찾아 파일에서 읽어 DB 업데이트.
    /// 앱 시작 시 백그라운드로 한 번 실행.
    func patchMissingDurations(backupRoot: URL) async {
        // Fetch NULL-duration video records using GRDB async read
        let records: [BackupAssetRecord]
        do {
            records = try await queue.read { db in
                try BackupAssetRecord
                    .filter(Column("media_type") == "video")
                    .filter(Column("duration_seconds") == nil)
                    .filter(Column("status") == "completed")
                    .fetchAll(db)
            }
        } catch {
            return
        }
        guard !records.isEmpty else { return }

        for record in records {
            let fileURL: URL
            if (record.finalPath as NSString).isAbsolutePath {
                fileURL = URL(fileURLWithPath: record.finalPath)
            } else {
                fileURL = backupRoot.appendingPathComponent(record.finalPath)
            }
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }

            let avAsset = AVURLAsset(url: fileURL)
            guard let duration = try? await avAsset.load(.duration) else { continue }
            let seconds = duration.seconds
            guard seconds.isFinite, seconds > 0 else { continue }

            _ = try? await queue.write { db in
                try db.execute(
                    sql: "UPDATE backup_assets SET duration_seconds = ? WHERE backup_id = ?",
                    arguments: [seconds, record.backupId]
                )
            }
        }
    }
}
