import Foundation
import Photos
import ICherriProtocol
import GRDB

struct PhotoLibraryScanPlan {
    enum Mode {
        case full
        case incremental
    }

    let mode: Mode
    let runAssets: [AssetMetadata]
    let runAssetCount: Int
    let runAssetBytes: Int64
    let libraryAssetCount: Int
    let libraryAssetBytes: Int64
}

// Retained for legacy test compatibility
struct PhotoLibraryScanIndexState: Codable {
    static let currentSchemaVersion = 2

    var schemaVersion = currentSchemaVersion
    var cachedAssetsByID: [String: AssetMetadata] = [:]
    var pendingAssetIDs: Set<String> = []
    var retryAssetIDs: Set<String> = []
    var fullScanCompleted = false
    var requiresReconcile = false
    var incrementalRunsSinceReconcile = 0

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        cachedAssetsByID = try container.decodeIfPresent([String: AssetMetadata].self, forKey: .cachedAssetsByID) ?? [:]
        pendingAssetIDs = try container.decodeIfPresent(Set<String>.self, forKey: .pendingAssetIDs) ?? []
        retryAssetIDs = try container.decodeIfPresent(Set<String>.self, forKey: .retryAssetIDs) ?? []
        fullScanCompleted = try container.decodeIfPresent(Bool.self, forKey: .fullScanCompleted) ?? false
        requiresReconcile = try container.decodeIfPresent(Bool.self, forKey: .requiresReconcile) ?? false
        incrementalRunsSinceReconcile = try container.decodeIfPresent(Int.self, forKey: .incrementalRunsSinceReconcile) ?? 0
    }
}

// Database Record Types for GRDB
private struct CachedAssetRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "cached_assets"
    
    let receiverID: String
    let deviceID: String
    let assetLocalID: String
    let originalFilename: String
    let mediaType: String
    let creationDate: Date
    let modificationDate: Date
    let byteSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let quickFingerprint: String
    let durationSeconds: Double?
    
    enum CodingKeys: String, CodingKey {
        case receiverID = "receiver_id"
        case deviceID = "device_id"
        case assetLocalID = "asset_local_id"
        case originalFilename = "original_filename"
        case mediaType = "media_type"
        case creationDate = "creation_date"
        case modificationDate = "modification_date"
        case byteSize = "byte_size"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case quickFingerprint = "quick_fingerprint"
        case durationSeconds = "duration_seconds"
    }
}

private struct PendingAssetRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pending_assets"
    
    let receiverID: String
    let assetLocalID: String
    let status: String // 'pending' or 'retry'
    
    enum CodingKeys: String, CodingKey {
        case receiverID = "receiver_id"
        case assetLocalID = "asset_local_id"
        case status
    }
}

private struct ScanStateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "scan_states"
    
    let receiverID: String
    let fullScanCompleted: Bool
    let requiresReconcile: Bool
    let incrementalRunsSinceReconcile: Int
    
    enum CodingKeys: String, CodingKey {
        case receiverID = "receiver_id"
        case fullScanCompleted = "full_scan_completed"
        case requiresReconcile = "requires_reconcile"
        case incrementalRunsSinceReconcile = "incremental_runs_since_reconcile"
    }
}

extension CachedAssetRecord {
    init(receiverID: String, metadata: AssetMetadata) {
        self.receiverID = receiverID
        self.deviceID = metadata.deviceID
        self.assetLocalID = metadata.assetLocalID
        self.originalFilename = metadata.originalFilename
        self.mediaType = metadata.mediaType.rawValue
        self.creationDate = metadata.creationDate
        self.modificationDate = metadata.modificationDate
        self.byteSize = metadata.byteSize
        self.pixelWidth = metadata.pixelWidth
        self.pixelHeight = metadata.pixelHeight
        self.quickFingerprint = metadata.quickFingerprint
        self.durationSeconds = metadata.durationSeconds
    }
    
    func toMetadata() -> AssetMetadata {
        AssetMetadata(
            deviceID: deviceID,
            assetLocalID: assetLocalID,
            originalFilename: originalFilename,
            mediaType: MediaType(rawValue: mediaType) ?? .photo,
            creationDate: creationDate,
            modificationDate: modificationDate,
            byteSize: byteSize,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            quickFingerprint: quickFingerprint,
            durationSeconds: durationSeconds
        )
    }
}

@MainActor
final class PhotoLibraryScanIndexStore: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoLibraryScanIndexStore()

    private let reconcileInterval = 10
    private var activeReceiverID: String?
    private var sanitizedActiveReceiverID: String {
        guard let id = activeReceiverID else { return "" }
        return id.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
    private var fetchResult: PHFetchResult<PHAsset>?
    private var isObserving = false
    
    private let dbQueue: DatabaseQueue

    private override init() {
        self.activeReceiverID = UserDefaults.standard.string(forKey: "iCherriReceiverID")
        
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("iCherri", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dbURL = directory.appendingPathComponent("photo-scan-index.db")
        
        var config = Configuration()
        config.journalMode = .wal
        let queue = try! DatabaseQueue(path: dbURL.path, configuration: config)
        
        try! queue.write { db in
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS scan_states (
                receiver_id TEXT PRIMARY KEY,
                full_scan_completed INTEGER NOT NULL DEFAULT 0,
                requires_reconcile INTEGER NOT NULL DEFAULT 0,
                incremental_runs_since_reconcile INTEGER NOT NULL DEFAULT 0
            );
            """)
            
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS cached_assets (
                receiver_id TEXT NOT NULL,
                device_id TEXT NOT NULL,
                asset_local_id TEXT NOT NULL,
                original_filename TEXT NOT NULL,
                media_type TEXT NOT NULL,
                creation_date REAL NOT NULL,
                modification_date REAL NOT NULL,
                byte_size INTEGER NOT NULL,
                pixel_width INTEGER NOT NULL,
                pixel_height INTEGER NOT NULL,
                quick_fingerprint TEXT NOT NULL,
                duration_seconds REAL,
                PRIMARY KEY (receiver_id, asset_local_id)
            );
            """)
            
            try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS pending_assets (
                receiver_id TEXT NOT NULL,
                asset_local_id TEXT NOT NULL,
                status TEXT NOT NULL,
                PRIMARY KEY (receiver_id, asset_local_id)
            );
            """)
        }
        
        self.dbQueue = queue
        super.init()
        migrateLegacyJSONToSQLite()
    }

    func switchReceiver(to receiverID: String?) {
        self.activeReceiverID = receiverID
    }

    deinit {
        if isObserving {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }

    func startObserving() {
        guard !isObserving else { return }
        fetchResult = Self.makeFetchResult()
        PHPhotoLibrary.shared().register(self)
        isObserving = true
    }

    private func getScanState(for receiverID: String) -> ScanStateRecord {
        try! dbQueue.read { db in
            try ScanStateRecord.filter(Column("receiver_id") == receiverID).fetchOne(db)
        } ?? ScanStateRecord(
            receiverID: receiverID,
            fullScanCompleted: false,
            requiresReconcile: false,
            incrementalRunsSinceReconcile: 0
        )
    }
    
    private func saveScanState(_ record: ScanStateRecord) {
        try! dbQueue.write { db in
            try record.save(db)
        }
    }

    private func migrateLegacyJSONToSQLite() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("iCherri", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        let jsonFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("photo-scan-index") }
        
        guard !jsonFiles.isEmpty else { return }
        
        for fileURL in jsonFiles {
            let filename = fileURL.deletingPathExtension().lastPathComponent
            let receiverID: String
            if filename == "photo-scan-index" {
                receiverID = ""
            } else {
                receiverID = filename.replacingOccurrences(of: "photo-scan-index-", with: "")
            }
            
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? JSONDecoder().decode(PhotoLibraryScanIndexState.self, from: data)
            else {
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }
            
            try? dbQueue.write { db in
                let scanState = ScanStateRecord(
                    receiverID: receiverID,
                    fullScanCompleted: state.fullScanCompleted,
                    requiresReconcile: state.requiresReconcile,
                    incrementalRunsSinceReconcile: state.incrementalRunsSinceReconcile
                )
                try scanState.save(db)
                
                for asset in state.cachedAssetsByID.values {
                    let record = CachedAssetRecord(receiverID: receiverID, metadata: asset)
                    try record.save(db)
                }
                
                for assetID in state.pendingAssetIDs {
                    let record = PendingAssetRecord(receiverID: receiverID, assetLocalID: assetID, status: "pending")
                    try record.save(db)
                }
                
                for assetID in state.retryAssetIDs {
                    let record = PendingAssetRecord(receiverID: receiverID, assetLocalID: assetID, status: "retry")
                    try record.save(db)
                }
            }
            
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func makeScanPlan(
        scanner: PhotoLibraryScanner, 
        deviceID: String,
        progressHandler: ((Int, Int) -> Bool)? = nil
    ) async -> PhotoLibraryScanPlan {
        let totalCount = scanner.totalAssetCount()
        let receiverID = sanitizedActiveReceiverID
        let scanState = getScanState(for: receiverID)
        
        let hasCachedAssets = try! await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cached_assets WHERE receiver_id = ?", arguments: [receiverID]) ?? 0 > 0
        }
        
        if !scanState.fullScanCompleted || !hasCachedAssets || scanState.requiresReconcile || scanState.incrementalRunsSinceReconcile >= reconcileInterval {
            let cachedAssets: [String: AssetMetadata] = try! await dbQueue.read { db in
                let records = try CachedAssetRecord.filter(Column("receiver_id") == receiverID).fetchAll(db)
                return Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalID, $0.toMetadata()) })
            }
            
            let assets = await scanner.scanAllAssets(deviceID: deviceID, cachedAssets: cachedAssets, progressHandler: progressHandler)
            
            try! await dbQueue.write { db in
                try db.execute(sql: "DELETE FROM cached_assets WHERE receiver_id = ?", arguments: [receiverID])
                try db.execute(sql: "DELETE FROM pending_assets WHERE receiver_id = ?", arguments: [receiverID])
                
                for asset in assets {
                    let record = CachedAssetRecord(receiverID: receiverID, metadata: asset)
                    try record.insert(db)
                }
                
                let newScanState = ScanStateRecord(
                    receiverID: receiverID,
                    fullScanCompleted: true,
                    requiresReconcile: false,
                    incrementalRunsSinceReconcile: 0
                )
                try newScanState.save(db)
            }
            
            let libraryAssets = assets.sorted { $0.creationDate > $1.creationDate }
            let libraryBytes = libraryAssets.reduce(Int64(0)) { $0 + max($1.byteSize, 0) }
            
            return PhotoLibraryScanPlan(
                mode: .full,
                runAssets: libraryAssets,
                runAssetCount: libraryAssets.count,
                runAssetBytes: libraryBytes,
                libraryAssetCount: totalCount,
                libraryAssetBytes: libraryBytes
            )
        }
        
        let pendingRecords = try! await dbQueue.read { db in
            try PendingAssetRecord.filter(Column("receiver_id") == receiverID).fetchAll(db)
        }
        let candidateIDs = pendingRecords.map(\.assetLocalID)
        
        guard !candidateIDs.isEmpty else {
            let libraryBytes = try! await dbQueue.read { db in
                try Int64.fetchOne(db, sql: "SELECT SUM(byte_size) FROM cached_assets WHERE receiver_id = ?", arguments: [receiverID]) ?? 0
            }
            return PhotoLibraryScanPlan(
                mode: .incremental,
                runAssets: [],
                runAssetCount: 0,
                runAssetBytes: 0,
                libraryAssetCount: totalCount,
                libraryAssetBytes: libraryBytes
            )
        }
        
        let cachedAssets: [String: AssetMetadata] = try! await dbQueue.read { db in
            let records = try CachedAssetRecord.filter(Column("receiver_id") == receiverID && candidateIDs.contains(Column("asset_local_id"))).fetchAll(db)
            return Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalID, $0.toMetadata()) })
        }
        
        let assets = await scanner.scanAssets(localIdentifiers: candidateIDs, deviceID: deviceID, cachedAssets: cachedAssets, progressHandler: progressHandler)
        let resolvedIDs = Set(assets.map(\.assetLocalID))
        
        try! await dbQueue.write { db in
            for asset in assets {
                let record = CachedAssetRecord(receiverID: receiverID, metadata: asset)
                try record.save(db)
                try db.execute(sql: "DELETE FROM pending_assets WHERE receiver_id = ? AND asset_local_id = ?", arguments: [receiverID, asset.assetLocalID])
            }
            
            let missingIDs = Set(candidateIDs).subtracting(resolvedIDs)
            for assetID in missingIDs {
                try db.execute(sql: "DELETE FROM cached_assets WHERE receiver_id = ? AND asset_local_id = ?", arguments: [receiverID, assetID])
                try db.execute(sql: "DELETE FROM pending_assets WHERE receiver_id = ? AND asset_local_id = ?", arguments: [receiverID, assetID])
            }
        }
        
        let runAssets = assets.sorted { $0.creationDate > $1.creationDate }
        let libraryBytes = try! await dbQueue.read { db in
            try Int64.fetchOne(db, sql: "SELECT SUM(byte_size) FROM cached_assets WHERE receiver_id = ?", arguments: [receiverID]) ?? 0
        }
        
        return PhotoLibraryScanPlan(
            mode: .incremental,
            runAssets: runAssets,
            runAssetCount: runAssets.count,
            runAssetBytes: runAssets.reduce(Int64(0)) { $0 + max($1.byteSize, 0) },
            libraryAssetCount: totalCount,
            libraryAssetBytes: libraryBytes
        )
    }

    func markRetryRequired(assetIDs: [String]) {
        let receiverID = sanitizedActiveReceiverID
        try! dbQueue.write { db in
            for assetID in assetIDs {
                let record = PendingAssetRecord(receiverID: receiverID, assetLocalID: assetID, status: "retry")
                try record.save(db)
            }
        }
    }

    func markSucceeded(assetIDs: [String]) {
        let receiverID = sanitizedActiveReceiverID
        try! dbQueue.write { db in
            for assetID in assetIDs {
                try db.execute(sql: "DELETE FROM pending_assets WHERE receiver_id = ? AND asset_local_id = ?", arguments: [receiverID, assetID])
            }
        }
    }

    func finishBackupRun(mode: PhotoLibraryScanPlan.Mode) {
        let receiverID = sanitizedActiveReceiverID
        let scanState = getScanState(for: receiverID)
        let newScanState = ScanStateRecord(
            receiverID: receiverID,
            fullScanCompleted: scanState.fullScanCompleted,
            requiresReconcile: scanState.requiresReconcile,
            incrementalRunsSinceReconcile: mode == .full ? 0 : scanState.incrementalRunsSinceReconcile + 1
        )
        saveScanState(newScanState)
    }

    func markRequiresReconcile() {
        let receiverID = sanitizedActiveReceiverID
        let scanState = getScanState(for: receiverID)
        let newScanState = ScanStateRecord(
            receiverID: receiverID,
            fullScanCompleted: scanState.fullScanCompleted,
            requiresReconcile: true,
            incrementalRunsSinceReconcile: scanState.incrementalRunsSinceReconcile
        )
        saveScanState(newScanState)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let receiverID = self.sanitizedActiveReceiverID
            guard let currentFetchResult = self.fetchResult else {
                self.fetchResult = Self.makeFetchResult()
                let scanState = self.getScanState(for: receiverID)
                let newScanState = ScanStateRecord(
                    receiverID: receiverID,
                    fullScanCompleted: scanState.fullScanCompleted,
                    requiresReconcile: true,
                    incrementalRunsSinceReconcile: scanState.incrementalRunsSinceReconcile
                )
                self.saveScanState(newScanState)
                return
            }

            guard let details = changeInstance.changeDetails(for: currentFetchResult) else { return }
            let updatedFetchResult = details.fetchResultAfterChanges

            if details.hasIncrementalChanges {
                try! await dbQueue.write { db in
                    if let insertedIndexes = details.insertedIndexes {
                        for index in insertedIndexes {
                            let assetID = updatedFetchResult.object(at: index).localIdentifier
                            let record = PendingAssetRecord(receiverID: receiverID, assetLocalID: assetID, status: "pending")
                            try record.save(db)
                        }
                    }

                    if let changedIndexes = details.changedIndexes {
                        for index in changedIndexes {
                            let assetID = updatedFetchResult.object(at: index).localIdentifier
                            let record = PendingAssetRecord(receiverID: receiverID, assetLocalID: assetID, status: "pending")
                            try record.save(db)
                        }
                    }

                    if let removedIndexes = details.removedIndexes {
                        for index in removedIndexes {
                            let removedID = currentFetchResult.object(at: index).localIdentifier
                            try db.execute(sql: "DELETE FROM cached_assets WHERE receiver_id = ? AND asset_local_id = ?", arguments: [receiverID, removedID])
                            try db.execute(sql: "DELETE FROM pending_assets WHERE receiver_id = ? AND asset_local_id = ?", arguments: [receiverID, removedID])
                        }
                    }
                }
            } else {
                let scanState = self.getScanState(for: receiverID)
                let newScanState = ScanStateRecord(
                    receiverID: receiverID,
                    fullScanCompleted: scanState.fullScanCompleted,
                    requiresReconcile: true,
                    incrementalRunsSinceReconcile: scanState.incrementalRunsSinceReconcile
                )
                self.saveScanState(newScanState)
            }

            self.fetchResult = updatedFetchResult
        }
    }

    private static func makeFetchResult() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: options)
    }

    func reset() {
        let receiverID = sanitizedActiveReceiverID
        try! dbQueue.write { db in
            try db.execute(sql: "DELETE FROM cached_assets WHERE receiver_id = ?", arguments: [receiverID])
            try db.execute(sql: "DELETE FROM pending_assets WHERE receiver_id = ?", arguments: [receiverID])
            try db.execute(sql: "DELETE FROM scan_states WHERE receiver_id = ?", arguments: [receiverID])
        }
    }
}
