import Foundation
import Photos
import ICherriProtocol

struct PhotoLibraryScanPlan {
    enum Mode {
        case full
        case incremental
    }

    let mode: Mode
    let assets: [AssetMetadata]
    let totalAssetCount: Int
}

private struct PhotoLibraryScanIndexState: Codable {
    var cachedAssetsByID: [String: AssetMetadata] = [:]
    var pendingAssetIDs: Set<String> = []
    var retryAssetIDs: Set<String> = []
    var fullScanCompleted = false
    var requiresReconcile = false
    var incrementalRunsSinceReconcile = 0
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
            let assets = await scanner.scanAllAssets(deviceID: deviceID)
            state.cachedAssetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.assetLocalID, $0) })
            state.pendingAssetIDs.removeAll()
            state.requiresReconcile = false
            state.fullScanCompleted = true
            state.incrementalRunsSinceReconcile = 0
            persist()
            return PhotoLibraryScanPlan(mode: .full, assets: assets, totalAssetCount: totalCount)
        }

        let candidateIDs = Array(state.pendingAssetIDs.union(state.retryAssetIDs))
        guard !candidateIDs.isEmpty else {
            return PhotoLibraryScanPlan(mode: .incremental, assets: [], totalAssetCount: totalCount)
        }

        let assets = await scanner.scanAssets(localIdentifiers: candidateIDs, deviceID: deviceID)
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
        return PhotoLibraryScanPlan(mode: .incremental, assets: assets, totalAssetCount: totalCount)
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
}
