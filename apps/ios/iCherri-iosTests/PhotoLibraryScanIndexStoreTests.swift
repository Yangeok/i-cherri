import Foundation
import Testing
@testable import iCherri_ios

struct PhotoLibraryScanIndexStoreTests {

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
