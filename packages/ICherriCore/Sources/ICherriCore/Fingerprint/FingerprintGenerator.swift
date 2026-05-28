import Foundation
import ICherriProtocol

// Generates the quick_fingerprint string for metadata-based deduplication (Stage 2).
public enum FingerprintGenerator {
    // Format: {unix_timestamp}_{byteSize}_{pixelWidth}_{pixelHeight}
    public static func generate(from metadata: AssetMetadata) -> String {
        let ts = Int64(metadata.creationDate.timeIntervalSince1970)
        return "\(ts)_\(metadata.byteSize)_\(metadata.pixelWidth)_\(metadata.pixelHeight)"
    }

    public static func generate(
        creationDate: Date,
        byteSize: Int64,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> String {
        let ts = Int64(creationDate.timeIntervalSince1970)
        return "\(ts)_\(byteSize)_\(pixelWidth)_\(pixelHeight)"
    }
}
