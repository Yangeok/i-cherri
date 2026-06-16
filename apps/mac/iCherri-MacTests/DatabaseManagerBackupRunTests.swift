import Foundation
import Testing
import ICherriCore
import ICherriProtocol
@testable import iCherri_Mac

@Suite(.serialized)
struct DatabaseManagerBackupRunTests {

    @Test("Given a receiver snapshot with exact and fingerprint matches, when finalizing a backup run, then only truly missing assets remain")
    func finalizeBackupRunCountsCoveredAssets() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-backup-run-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: device.deviceID,
                deviceName: device.deviceName,
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-1"
            )
        )
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: "device-2",
                deviceName: "Another iPhone",
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-2"
            )
        )

        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-exact",
                deviceID: device.deviceID,
                assetLocalID: "exact",
                quickFingerprint: "fp-exact"
            )
        )
        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-shared",
                deviceID: "device-2",
                assetLocalID: "shared",
                quickFingerprint: "fp-shared"
            )
        )

        let snapshotAssets = [
            asset(id: "exact", fingerprint: "fp-exact", bytes: 100),
            asset(id: "duplicate", fingerprint: "fp-shared", bytes: 200),
            asset(id: "missing", fingerprint: "fp-missing", bytes: 300)
        ]
        try await manager.replaceBackupRunSnapshot(
            runID: "run-1",
            device: device,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: snapshotAssets.count, totalAssetBytes: 600),
            candidates: snapshotAssets
        )

        let result = try await manager.finalizeBackupRun(runID: "run-1", deviceID: device.deviceID)

        #expect(result.status == "partial")
        #expect(result.totalAssetCount == 3)
        #expect(result.completedAssetCount == 2)
        #expect(result.missingAssetIDs == ["missing"])
    }

    @Test("Given the latest receiver snapshot when loading coverage summaries then the latest run reports current library coverage counts")
    func fetchLatestBackupCoverageSummariesUsesNewestRun() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-backup-run-coverage-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: device.deviceID,
                deviceName: device.deviceName,
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-1"
            )
        )
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: "device-2",
                deviceName: "Another iPhone",
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-2"
            )
        )

        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-exact",
                deviceID: device.deviceID,
                assetLocalID: "kept",
                quickFingerprint: "fp-kept"
            )
        )
        try await manager.insertBackupAsset(
            backupAssetRecord(
                backupID: "backup-shared",
                deviceID: "device-2",
                assetLocalID: "shared",
                quickFingerprint: "fp-shared"
            )
        )

        try await manager.replaceBackupRunSnapshot(
            runID: "run-old",
            device: device,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: 1, totalAssetBytes: 100),
            candidates: [asset(id: "old", fingerprint: "fp-old", bytes: 100)]
        )
        try await manager.replaceBackupRunSnapshot(
            runID: "run-new",
            device: device,
            librarySnapshot: CheckBatchLibrarySnapshot(totalAssetCount: 3, totalAssetBytes: 600),
            candidates: [
                asset(id: "kept", fingerprint: "fp-kept", bytes: 100),
                asset(id: "shared", fingerprint: "fp-shared", bytes: 200),
                asset(id: "missing", fingerprint: "fp-missing", bytes: 300),
            ]
        )

        let summaries = try await manager.fetchLatestBackupCoverageSummaries()
        let summary = try #require(summaries.first(where: { $0.deviceId == device.deviceID }))

        #expect(summary.runId == "run-new")
        #expect(summary.totalAssetCount == 3)
        #expect(summary.completedAssetCount == 2)
        #expect(summary.pendingAssetCount == 1)
        #expect(summary.status == "snapshot_recorded")
    }

    @Test("Given an identical file already exists at the canonical destination when committing then the processor reuses it without creating a suffixed duplicate")
    func fileCommitReusesIdenticalExistingFile() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-file-commit-reuse-tests-\(UUID().uuidString)", isDirectory: true)
        let backupRoot = tempDirectory.appendingPathComponent("backup-root", isDirectory: true)
        let uploadRoot = tempDirectory.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: uploadRoot, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: "device-1",
                deviceName: "Test iPhone",
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-1"
            )
        )

        let existingDir = backupRoot.appendingPathComponent("2026/06", isDirectory: true)
        try FileManager.default.createDirectory(at: existingDir, withIntermediateDirectories: true)
        let existingURL = existingDir.appendingPathComponent("IMG_0001.JPG")
        let contents = Data("same-bytes".utf8)
        try contents.write(to: existingURL)

        let tempURL = uploadRoot.appendingPathComponent("upload.tmp")
        try contents.write(to: tempURL)
        let sha256 = try StreamingHasher().hash(fileURL: tempURL)

        let processor = FileCommitProcessor(backupRootURL: backupRoot, dbManager: manager)
        let result = try await processor.commit(
            .init(
                uploadID: "upload-1",
                deviceID: "device-1",
                assetLocalID: "asset-1",
                originalFilename: "IMG_0001.JPG",
                mediaType: .photo,
                creationDate: iso8601("2026-06-08T12:00:00Z"),
                modificationDate: iso8601("2026-06-08T12:00:00Z"),
                byteSize: Int64(contents.count),
                pixelWidth: 100,
                pixelHeight: 100,
                quickFingerprint: "fp-1",
                durationSeconds: nil,
                tempPath: tempURL.path,
                expectedByteSize: Int64(contents.count),
                expectedSHA256: sha256
            )
        )

        let displayPath: String
        switch result {
        case .success(_, let path):
            displayPath = path
        default:
            Issue.record("Expected commit success")
            return
        }

        #expect(displayPath == "2026/06/IMG_0001.JPG")
        #expect(FileManager.default.fileExists(atPath: existingURL.path))
        #expect(!FileManager.default.fileExists(atPath: existingDir.appendingPathComponent("IMG_0001_1.JPG").path))
        #expect(!FileManager.default.fileExists(atPath: tempURL.path))

        let record = try #require(try await manager.fetchAsset(deviceId: "device-1", assetLocalId: "asset-1"))
        #expect(record.finalPath == "2026/06/IMG_0001.JPG")
        #expect(record.contentSha256 == sha256)
    }

    @Test("Given a conflicting filename with different bytes when committing then the processor still creates a suffixed file to avoid overwrite")
    func fileCommitKeepsSuffixForDifferentContentCollision() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-file-commit-collision-tests-\(UUID().uuidString)", isDirectory: true)
        let backupRoot = tempDirectory.appendingPathComponent("backup-root", isDirectory: true)
        let uploadRoot = tempDirectory.appendingPathComponent("incoming", isDirectory: true)
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: uploadRoot, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: "device-1",
                deviceName: "Test iPhone",
                pairingStatus: "paired",
                createdAt: now,
                lastSeenAt: now,
                trustToken: "token-1"
            )
        )

        let existingDir = backupRoot.appendingPathComponent("2026/06", isDirectory: true)
        try FileManager.default.createDirectory(at: existingDir, withIntermediateDirectories: true)
        let existingURL = existingDir.appendingPathComponent("IMG_0001.JPG")
        try Data("old-bytes".utf8).write(to: existingURL)

        let tempURL = uploadRoot.appendingPathComponent("upload.tmp")
        let newContents = Data("new-bytes".utf8)
        try newContents.write(to: tempURL)
        let sha256 = try StreamingHasher().hash(fileURL: tempURL)

        let processor = FileCommitProcessor(backupRootURL: backupRoot, dbManager: manager)
        let result = try await processor.commit(
            .init(
                uploadID: "upload-2",
                deviceID: "device-1",
                assetLocalID: "asset-2",
                originalFilename: "IMG_0001.JPG",
                mediaType: .photo,
                creationDate: iso8601("2026-06-08T12:00:00Z"),
                modificationDate: iso8601("2026-06-08T12:00:00Z"),
                byteSize: Int64(newContents.count),
                pixelWidth: 100,
                pixelHeight: 100,
                quickFingerprint: "fp-2",
                durationSeconds: nil,
                tempPath: tempURL.path,
                expectedByteSize: Int64(newContents.count),
                expectedSHA256: sha256
            )
        )

        let displayPath: String
        switch result {
        case .success(_, let path):
            displayPath = path
        default:
            Issue.record("Expected commit success")
            return
        }

        #expect(displayPath == "2026/06/IMG_0001_1.JPG")
        #expect(FileManager.default.fileExists(atPath: existingDir.appendingPathComponent("IMG_0001_1.JPG").path))
    }

    @Test("Given only an on-disk backup file remains when check-batch runs then disk fallback skips upload and rebuilds the asset index")
    func diskFallbackRehydratesDeletedIndexFromExistingFile() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-disk-fallback-tests-\(UUID().uuidString)", isDirectory: true)
        let backupRoot = tempDirectory.appendingPathComponent("backup-root", isDirectory: true)
        try FileManager.default.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let device = DeviceInfo(deviceID: "device-1", deviceName: "Test iPhone", platform: "iOS", appVersion: "1.0")
        try await manager.upsertDevice(
            PairedDeviceRecord(
                id: nil,
                deviceId: device.deviceID,
                deviceName: device.deviceName,
                pairingStatus: "paired",
                createdAt: .now,
                lastSeenAt: .now,
                trustToken: "token-1"
            )
        )

        let creationDate = iso8601("2026-06-08T12:00:00Z")
        let existingDir = backupRoot.appendingPathComponent("2026/06", isDirectory: true)
        try FileManager.default.createDirectory(at: existingDir, withIntermediateDirectories: true)
        let existingURL = existingDir.appendingPathComponent("IMG_9000.PNG")
        let pngData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5xL0YAAAAASUVORK5CYII="))
        try pngData.write(to: existingURL)

        let candidate = AssetMetadata(
            deviceID: device.deviceID,
            assetLocalID: "asset-disk",
            originalFilename: "IMG_9000.PNG",
            mediaType: .photo,
            creationDate: creationDate,
            modificationDate: creationDate,
            byteSize: Int64(pngData.count),
            pixelWidth: 1,
            pixelHeight: 1,
            quickFingerprint: FingerprintGenerator.generate(
                creationDate: creationDate,
                byteSize: Int64(pngData.count),
                pixelWidth: 1,
                pixelHeight: 1
            )
        )

        let processor = CheckBatchProcessor(
            index: DiskBackedBackupIndex(databaseManager: manager, backupRootURL: backupRoot)
        )
        let response = try await processor.process(
            request: CheckBatchRequest(device: device, candidates: [candidate])
        )

        #expect(response.requiredUploads.isEmpty)
        #expect(response.alreadyBackedUp.isEmpty)
        #expect(response.duplicates == ["asset-disk"])

        let rehydrated = try #require(try await manager.fetchAsset(deviceId: device.deviceID, assetLocalId: "asset-disk"))
        #expect(rehydrated.finalPath == "2026/06/IMG_9000.PNG")
        #expect(rehydrated.status == "completed")
        #expect(!rehydrated.contentSha256.isEmpty)
    }

    @Test("Given upload sessions share an asset but differ by auto backup context when fetching reusable sessions then the matching context wins")
    func uploadSessionReusePrefersMatchingAutoBackupContext() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-upload-session-context-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let now = Date()
        let exactContext = UploadSessionRecord(
            uploadId: "upload-context",
            deviceId: "device-1",
            assetLocalId: "asset-1",
            backupRunId: "run-1",
            clientSessionId: "session-1",
            tempPath: tempDirectory.appendingPathComponent("context.tmp").path,
            expectedByteSize: 100,
            receivedBytes: 50,
            chunkSize: 8,
            status: "receiving",
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(3600),
            metadataJson: "{}",
            lastError: nil
        )
        let fallbackContext = UploadSessionRecord(
            uploadId: "upload-fallback",
            deviceId: "device-1",
            assetLocalId: "asset-1",
            backupRunId: nil,
            clientSessionId: nil,
            tempPath: tempDirectory.appendingPathComponent("fallback.tmp").path,
            expectedByteSize: 100,
            receivedBytes: 10,
            chunkSize: 8,
            status: "paused",
            createdAt: now,
            updatedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(3600),
            metadataJson: "{}",
            lastError: nil
        )

        try await manager.insertUploadSession(exactContext)
        try await manager.insertUploadSession(fallbackContext)

        let exactMatch = try #require(
            try await manager.fetchActiveUploadSession(
                deviceId: "device-1",
                assetLocalId: "asset-1",
                expectedByteSize: 100,
                backupRunId: "run-1",
                clientSessionId: "session-1"
            )
        )
        let fallbackMatch = try #require(
            try await manager.fetchActiveUploadSession(
                deviceId: "device-1",
                assetLocalId: "asset-1",
                expectedByteSize: 100
            )
        )

        #expect(exactMatch.uploadId == "upload-context")
        #expect(fallbackMatch.uploadId == "upload-context")
        #expect(exactMatch.backupRunId == "run-1")
        #expect(exactMatch.clientSessionId == "session-1")
    }

    @Test("Given an already persisted chunk when replaying the same chunk then the receiver treats it as idempotent and keeps progress unchanged")
    func replayedChunkKeepsProgressUnchanged() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-upload-chunk-replay-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let sessionManager = SessionManager(dbManager: manager)
        let handler = UploadHandler(sessionManager: sessionManager, incomingDir: tempDirectory)
        let uploadID = "upload-replay"
        let tempPath = tempDirectory.appendingPathComponent("\(uploadID).tmp")
        FileManager.default.createFile(atPath: tempPath.path, contents: Data(repeating: 0, count: 16))

        try await sessionManager.createSession(
            uploadID: uploadID,
            deviceID: "device-1",
            assetLocalID: "asset-1",
            backupRunID: "run-1",
            clientSessionID: "session-1",
            tempPath: tempPath.path,
            expectedByteSize: 16,
            chunkSize: 8,
            expiresAt: Date().addingTimeInterval(3600),
            metadataJson: "{}"
        )
        try await sessionManager.updateProgress(uploadID: uploadID, receivedBytes: 8, status: "receiving")

        let request = HTTPRequest(
            method: "PUT",
            path: "/uploads/\(uploadID)/chunks/0",
            headers: [:],
            body: Data(repeating: 0xAB, count: 8)
        )
        let response = await handler.handleChunk(request, uploadID: uploadID, chunkIndex: 0)
        let payload = try JSONDecoder().decode(ChunkUploadResponse.self, from: response.body)
        let session = try #require(try await sessionManager.fetchSession(uploadID: uploadID))

        #expect(response.statusCode == 200)
        #expect(payload.receivedBytes == 8)
        #expect(session.receivedBytes == 8)
    }

    @Test("Given a chunk offset that skips unread bytes when uploading then the receiver rejects the gap with conflict")
    func outOfOrderChunkReturnsConflict() async throws {
        let manager = DatabaseManager.shared
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icherri-upload-chunk-gap-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let databasePath = tempDirectory.appendingPathComponent("receiver.sqlite").path
        try await manager.open(at: databasePath)

        let sessionManager = SessionManager(dbManager: manager)
        let handler = UploadHandler(sessionManager: sessionManager, incomingDir: tempDirectory)
        let uploadID = "upload-gap"
        let tempPath = tempDirectory.appendingPathComponent("\(uploadID).tmp")
        FileManager.default.createFile(atPath: tempPath.path, contents: Data(repeating: 0, count: 16))

        try await sessionManager.createSession(
            uploadID: uploadID,
            deviceID: "device-1",
            assetLocalID: "asset-1",
            backupRunID: "run-1",
            clientSessionID: "session-1",
            tempPath: tempPath.path,
            expectedByteSize: 16,
            chunkSize: 8,
            expiresAt: Date().addingTimeInterval(3600),
            metadataJson: "{}"
        )

        let request = HTTPRequest(
            method: "PUT",
            path: "/uploads/\(uploadID)/chunks/1",
            headers: [:],
            body: Data(repeating: 0xCD, count: 8)
        )
        let response = await handler.handleChunk(request, uploadID: uploadID, chunkIndex: 1)
        let body = String(data: response.body, encoding: .utf8) ?? ""
        let session = try #require(try await sessionManager.fetchSession(uploadID: uploadID))

        #expect(response.statusCode == 409)
        #expect(body.contains("invalid_chunk_offset"))
        #expect(session.receivedBytes == 0)
    }

    private func asset(id: String, fingerprint: String, bytes: Int64) -> AssetMetadata {
        AssetMetadata(
            deviceID: "device-1",
            assetLocalID: id,
            originalFilename: "\(id).JPG",
            mediaType: .photo,
            creationDate: .now,
            modificationDate: .now,
            byteSize: bytes,
            pixelWidth: 100,
            pixelHeight: 100,
            quickFingerprint: fingerprint
        )
    }

    private func backupAssetRecord(
        backupID: String,
        deviceID: String,
        assetLocalID: String,
        quickFingerprint: String
    ) -> BackupAssetRecord {
        BackupAssetRecord(
            id: nil,
            backupId: backupID,
            deviceId: deviceID,
            assetLocalId: assetLocalID,
            originalFilename: "\(assetLocalID).JPG",
            mediaType: MediaType.photo.rawValue,
            creationDate: .now,
            modificationDate: .now,
            byteSize: 100,
            durationSeconds: nil,
            pixelWidth: 100,
            pixelHeight: 100,
            quickFingerprint: quickFingerprint,
            contentSha256: "\(backupID)-sha",
            finalPath: "2026/06/\(assetLocalID).JPG",
            status: "completed",
            duplicateOfBackupId: nil,
            firstSeenAt: .now,
            completedAt: .now,
            lastError: nil
        )
    }

    private func iso8601(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value) ?? .distantPast
    }
}
