import XCTest
import ICherriProtocol
@testable import ICherriCore

final class AutoBackupStateMachineTests: XCTestCase {

    func testScheduledRunBecomesPreparingWhenEligible() throws {
        let nextState = try AutoBackupStateMachine.transition(
            runState: .scheduled,
            event: .policyEvaluated(isEligible: true)
        )

        XCTAssertEqual(nextState, .preparing)
    }

    func testPreparingRunBecomesUploadingAfterStaging() throws {
        let nextState = try AutoBackupStateMachine.transition(
            runState: .preparing,
            event: .stagedFilesPrepared
        )

        XCTAssertEqual(nextState, .uploading)
    }

    func testPartialRunCanRestartPreparationWhenEligibilityReturns() throws {
        let nextState = try AutoBackupStateMachine.transition(
            runState: .partial,
            event: .policyEvaluated(isEligible: true)
        )

        XCTAssertEqual(nextState, .preparing)
    }

    func testUploadingAssetCanBecomeFailedRetained() throws {
        let nextState = try AutoBackupStateMachine.transition(
            assetState: .uploading,
            event: .failRetained
        )

        XCTAssertEqual(nextState, .failedRetained)
    }

    func testFailedRetainedAssetCanBeRequeued() throws {
        let nextState = try AutoBackupStateMachine.transition(
            assetState: .failedRetained,
            event: .requeue
        )

        XCTAssertEqual(nextState, .queued)
    }
}
