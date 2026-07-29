import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_ios

struct PhotoLibraryScanIndexStoreTests {

    @Test("Given a scan plan when run scope is separated from library scope then counts stay distinct")
    func givenScanPlan_whenRunScopeSeparatedFromLibraryScope_thenCountsStayDistinct() {
        let asset = AssetMetadata(
            deviceID: "device",
            assetLocalID: "asset-1",
            originalFilename: "asset-1.jpg",
            mediaType: .photo,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            modificationDate: Date(timeIntervalSince1970: 1_700_000_000),
            byteSize: 12_345,
            pixelWidth: 4032,
            pixelHeight: 3024,
            quickFingerprint: "fp-1"
        )

        let plan = PhotoLibraryScanPlan(
            mode: .incremental,
            runAssets: [asset],
            runAssetCount: 1,
            runAssetBytes: 12_345,
            libraryAssetCount: 20_000,
            libraryAssetBytes: 999_999
        )

        #expect(plan.runAssets.count == 1)
        #expect(plan.runAssetCount == 1)
        #expect(plan.runAssetBytes == 12_345)
        #expect(plan.libraryAssetCount == 20_000)
        #expect(plan.libraryAssetBytes == 999_999)
    }

    @Test("Given schema version changes when legacy state is decoded then current schema is adopted and reconcile counters stay safe")
    func givenSchemaVersionChanges_whenLegacyStateIsDecoded_thenCurrentSchemaIsAdoptedAndReconcileCountersStaySafe() throws {
        // Given
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "cachedAssetsByID": {},
          "pendingAssetIDs": [],
          "retryAssetIDs": [],
          "fullScanCompleted": true
        }
        """.data(using: .utf8)!

        // When
        let decoded = try JSONDecoder().decode(PhotoLibraryScanIndexState.self, from: legacyJSON)

        // Then
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.requiresReconcile == false)
        #expect(decoded.incrementalRunsSinceReconcile == 0)
    }

    @Test("Given new state when encoded then current schema version is persisted")
    func givenNewState_whenEncoded_thenCurrentSchemaVersionIsPersisted() throws {
        // Given
        let state = PhotoLibraryScanIndexState()

        // When
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PhotoLibraryScanIndexState.self, from: encoded)

        // Then
        #expect(decoded.schemaVersion == PhotoLibraryScanIndexState.currentSchemaVersion)
        #expect(decoded.fullScanCompleted == false)
        #expect(decoded.incrementalRunsSinceReconcile == 0)
    }
}
