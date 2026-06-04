import Foundation
import Photos
import ICherriProtocol

public enum PhotoLibraryAuthStatus {
    case authorized
    case limited
    case denied
    case notDetermined
}

// Handles PHAsset access permission and scans all media assets from the photo library.
public final class PhotoLibraryScanner {
    public init() {}

    public func requestAuthorization() async -> PhotoLibraryAuthStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return mapStatus(status)
    }

    public func currentAuthorizationStatus() -> PhotoLibraryAuthStatus {
        mapStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    public func totalAssetCount() -> Int {
        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        return PHAsset.fetchAssets(with: options).count
    }

    // Scans all media assets and returns AssetMetadata array. Targets >1000 assets/sec.
    public func scanAllAssets(deviceID: String) async -> [AssetMetadata] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        let result = PHAsset.fetchAssets(with: options)
        var assets: [AssetMetadata] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            autoreleasepool {
                guard let metadata = Self.extractMetadata(from: asset, deviceID: deviceID) else { return }
                assets.append(metadata)
            }
        }

        return assets
    }

    public func scanAssets(localIdentifiers: [String], deviceID: String) async -> [AssetMetadata] {
        guard !localIdentifiers.isEmpty else { return [] }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assets: [AssetMetadata] = []
        assets.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            autoreleasepool {
                guard let metadata = Self.extractMetadata(from: asset, deviceID: deviceID) else { return }
                assets.append(metadata)
            }
        }

        return assets.sorted { lhs, rhs in
            lhs.creationDate > rhs.creationDate
        }
    }

    // Fetches raw file data for a given asset local identifier.
    public func fetchData(for assetLocalID: String) async throws -> Data {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalID], options: nil)
        guard let asset = result.firstObject else {
            throw PhotoScannerError.assetNotFound(assetLocalID)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .original
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: PhotoScannerError.dataUnavailable(assetLocalID))
                }
            }
        }
    }

    // Opens a streaming resource for a video asset, returning stream + file size.
    public func openInputStreamWithSize(for assetLocalID: String) async throws -> (InputStream, Int64) {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalID], options: nil)
        guard let asset = result.firstObject, asset.mediaType == .video else {
            throw PhotoScannerError.assetNotFound(assetLocalID)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .original
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let urlAsset = avAsset as? AVURLAsset,
                      let stream = InputStream(url: urlAsset.url),
                      let size = try? urlAsset.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                    continuation.resume(throwing: PhotoScannerError.dataUnavailable(assetLocalID))
                    return
                }
                continuation.resume(returning: (stream, Int64(size)))
            }
        }
    }

    // Opens a streaming resource for a video or large asset.
    public func openInputStream(for assetLocalID: String) async throws -> InputStream {
        let (stream, _) = try await openInputStreamWithSize(for: assetLocalID)
        return stream
    }

    // MARK: - Private

    private static func extractMetadata(from asset: PHAsset, deviceID: String) -> AssetMetadata? {
        guard let filename = (asset.value(forKey: "filename") as? String) ?? inferFilename(from: asset) else {
            return nil
        }
        let mediaType = resolveMediaType(asset)
        let creation = asset.creationDate ?? Date()
        let modification = asset.modificationDate ?? creation
        let byteSize = resolveByteSize(for: asset)
        let fingerprint = FingerprintBuilder.build(
            creationDate: creation,
            modificationDate: modification,
            byteSize: byteSize,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight
        )

        return AssetMetadata(
            deviceID: deviceID,
            assetLocalID: asset.localIdentifier,
            originalFilename: filename,
            mediaType: mediaType,
            creationDate: creation,
            modificationDate: modification,
            byteSize: byteSize,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            quickFingerprint: fingerprint,
            durationSeconds: asset.duration > 0 ? asset.duration : nil
        )
    }

    private static func resolveMediaType(_ asset: PHAsset) -> MediaType {
        switch asset.mediaType {
        case .image:
            return asset.mediaSubtypes.contains(.photoLive) ? .livePhotoComponent : .photo
        case .video:
            return .video
        default:
            return .unknown
        }
    }

    private static func inferFilename(from asset: PHAsset) -> String? {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename
    }

    private static func resolveByteSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        let resource = preferredResource(from: resources, mediaType: asset.mediaType) ?? resources.first
        guard let resource else { return 0 }

        if let size = resource.value(forKey: "fileSize") as? Int64 {
            return size
        }
        if let size = resource.value(forKey: "fileSize") as? NSNumber {
            return size.int64Value
        }
        return 0
    }

    private static func preferredResource(from resources: [PHAssetResource], mediaType: PHAssetMediaType) -> PHAssetResource? {
        switch mediaType {
        case .image:
            return resources.first {
                $0.type == .photo || $0.type == .fullSizePhoto || $0.type == .alternatePhoto
            }
        case .video:
            return resources.first {
                $0.type == .video || $0.type == .fullSizeVideo
            }
        default:
            return resources.first
        }
    }

    private func mapStatus(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthStatus {
        switch status {
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}

// Builds quick_fingerprint string from asset metadata fields.
enum FingerprintBuilder {
    static func build(creationDate: Date, modificationDate: Date, byteSize: Int64, pixelWidth: Int, pixelHeight: Int, durationSeconds: Double? = nil) -> String {
        let ts = Int64(creationDate.timeIntervalSince1970)
        if let dur = durationSeconds, dur > 0 {
            return "\(ts)_\(byteSize)_\(pixelWidth)_\(pixelHeight)_\(Int64(dur * 1000))"
        }
        return "\(ts)_\(byteSize)_\(pixelWidth)_\(pixelHeight)"
    }
}

enum PhotoScannerError: Error {
    case assetNotFound(String)
    case dataUnavailable(String)
    case permissionDenied
}
