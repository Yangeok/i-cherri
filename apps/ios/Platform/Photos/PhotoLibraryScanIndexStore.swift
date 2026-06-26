import Foundation
import Photos
import ICherriProtocol

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

@MainActor
final class PhotoLibraryScanIndexStore: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoLibraryScanIndexStore()

    private let reconcileInterval = 10
    private let fileURL: URL
    private var state = PhotoLibraryScanIndexState()
    private var fetchResult: PHFetchResult<PHAsset>?
    private var isObserving = false

    private override init() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("iCherri", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("photo-scan-index.json")
        super.init()
        loadState()
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

    func makeScanPlan(scanner: PhotoLibraryScanner, deviceID: String) async -> PhotoLibraryScanPlan {
        let totalCount = scanner.totalAssetCount()

        if !state.fullScanCompleted || state.cachedAssetsByID.isEmpty || state.requiresReconcile || state.incrementalRunsSinceReconcile >= reconcileInterval {
            let assets = await scanner.scanAllAssets(deviceID: deviceID, cachedAssets: state.cachedAssetsByID)
            state.cachedAssetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.assetLocalID, $0) })
            state.pendingAssetIDs.removeAll()
            state.requiresReconcile = false
            state.fullScanCompleted = true
            state.incrementalRunsSinceReconcile = 0
            persist()
            let libraryAssets = allKnownAssetsSorted()
            let libraryBytes = sumOfCachedAssetBytes()
            return PhotoLibraryScanPlan(
                mode: .full,
                runAssets: libraryAssets,
                runAssetCount: libraryAssets.count,
                runAssetBytes: libraryBytes,
                libraryAssetCount: totalCount,
                libraryAssetBytes: libraryBytes
            )
        }

        let candidateIDs = Array(state.pendingAssetIDs.union(state.retryAssetIDs))
        guard !candidateIDs.isEmpty else {
            return PhotoLibraryScanPlan(
                mode: .incremental,
                runAssets: [],
                runAssetCount: 0,
                runAssetBytes: 0,
                libraryAssetCount: totalCount,
                libraryAssetBytes: sumOfCachedAssetBytes()
            )
        }

        let assets = await scanner.scanAssets(localIdentifiers: candidateIDs, deviceID: deviceID, cachedAssets: state.cachedAssetsByID)
        let resolvedIDs = Set(assets.map(\.assetLocalID))

        for asset in assets {
            state.cachedAssetsByID[asset.assetLocalID] = asset
            state.pendingAssetIDs.remove(asset.assetLocalID)
        }

        let missingIDs = Set(candidateIDs).subtracting(resolvedIDs)
        for assetID in missingIDs {
            state.cachedAssetsByID.removeValue(forKey: assetID)
            state.pendingAssetIDs.remove(assetID)
            state.retryAssetIDs.remove(assetID)
        }

        persist()
        let runAssets = assets.sorted { lhs, rhs in
            lhs.creationDate > rhs.creationDate
        }
        return PhotoLibraryScanPlan(
            mode: .incremental,
            runAssets: runAssets,
            runAssetCount: runAssets.count,
            runAssetBytes: runAssets.reduce(Int64(0)) { partialResult, asset in
                partialResult + max(asset.byteSize, 0)
            },
            libraryAssetCount: totalCount,
            libraryAssetBytes: sumOfCachedAssetBytes()
        )
    }

    func markRetryRequired(assetIDs: [String]) {
        state.retryAssetIDs.formUnion(assetIDs)
        persist()
    }

    func markSucceeded(assetIDs: [String]) {
        for assetID in assetIDs {
            state.retryAssetIDs.remove(assetID)
            state.pendingAssetIDs.remove(assetID)
        }
        persist()
    }

    func finishBackupRun(mode: PhotoLibraryScanPlan.Mode) {
        switch mode {
        case .full:
            state.incrementalRunsSinceReconcile = 0
        case .incremental:
            state.incrementalRunsSinceReconcile += 1
        }
        persist()
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let currentFetchResult = self.fetchResult else {
                self.fetchResult = Self.makeFetchResult()
                self.state.requiresReconcile = true
                self.persist()
                return
            }

            guard let details = changeInstance.changeDetails(for: currentFetchResult) else { return }
            let updatedFetchResult = details.fetchResultAfterChanges

            if details.hasIncrementalChanges {
                if let insertedIndexes = details.insertedIndexes {
                    for index in insertedIndexes {
                        self.state.pendingAssetIDs.insert(updatedFetchResult.object(at: index).localIdentifier)
                    }
                }

                if let changedIndexes = details.changedIndexes {
                    for index in changedIndexes {
                        self.state.pendingAssetIDs.insert(updatedFetchResult.object(at: index).localIdentifier)
                    }
                }

                if let removedIndexes = details.removedIndexes {
                    for index in removedIndexes {
                        let removedID = currentFetchResult.object(at: index).localIdentifier
                        self.state.cachedAssetsByID.removeValue(forKey: removedID)
                        self.state.pendingAssetIDs.remove(removedID)
                        self.state.retryAssetIDs.remove(removedID)
                    }
                }
            } else {
                self.state.requiresReconcile = true
            }

            self.fetchResult = updatedFetchResult
            self.persist()
        }
    }

    private func loadState() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(PhotoLibraryScanIndexState.self, from: data)
        else {
            state = PhotoLibraryScanIndexState()
            return
        }

        guard decoded.schemaVersion == PhotoLibraryScanIndexState.currentSchemaVersion else {
            state = PhotoLibraryScanIndexState()
            return
        }

        state = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private static func makeFetchResult() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        return PHAsset.fetchAssets(with: options)
    }

    private func sumOfCachedAssetBytes() -> Int64 {
        state.cachedAssetsByID.values.reduce(Int64(0)) { partialResult, asset in
            partialResult + max(asset.byteSize, 0)
        }
    }

    private func allKnownAssetsSorted() -> [AssetMetadata] {
        state.cachedAssetsByID.values.sorted { lhs, rhs in
            lhs.creationDate > rhs.creationDate
        }
    }
}
