import Foundation
import ICherriProtocol

public enum AutoBackupStateMachineError: Error, Equatable, Sendable {
    case invalidRunTransition(from: AutoBackupRunState, event: AutoBackupRunEvent)
    case invalidAssetTransition(from: AutoBackupAssetState, event: AutoBackupAssetEvent)
}

public enum AutoBackupRunEvent: Equatable, Sendable {
    case policyEvaluated(isEligible: Bool)
    case stagedFilesPrepared
    case pause(reason: RunPauseReason)
    case resume
    case markCompleted
    case markPartial
    case expire
}

public enum AutoBackupAssetEvent: Equatable, Sendable {
    case stagePrepared
    case uploadStarted
    case committed
    case skippedDuplicate
    case failRetained
    case requeue
}

public enum AutoBackupStateMachine {
    public static func transition(
        runState: AutoBackupRunState,
        event: AutoBackupRunEvent
    ) throws -> AutoBackupRunState {
        switch (runState, event) {
        case (.scheduled, .policyEvaluated(isEligible: true)):
            return .preparing
        case (.scheduled, .policyEvaluated(isEligible: false)):
            return .eligibilityBlocked
        case (.eligibilityBlocked, .policyEvaluated(isEligible: true)):
            return .preparing
        case (.eligibilityBlocked, .policyEvaluated(isEligible: false)):
            return .eligibilityBlocked
        case (.preparing, .stagedFilesPrepared):
            return .uploading
        case (.uploading, .pause):
            return .paused
        case (.paused, .resume):
            return .uploading
        case (.uploading, .markCompleted):
            return .completed
        case (.uploading, .markPartial):
            return .partial
        case (.partial, .markCompleted):
            return .completed
        case (.partial, .policyEvaluated(isEligible: true)):
            return .preparing
        case (.scheduled, .expire),
             (.eligibilityBlocked, .expire),
             (.preparing, .expire),
             (.uploading, .expire),
             (.paused, .expire),
             (.partial, .expire):
            return .expired
        default:
            throw AutoBackupStateMachineError.invalidRunTransition(from: runState, event: event)
        }
    }

    public static func transition(
        assetState: AutoBackupAssetState,
        event: AutoBackupAssetEvent
    ) throws -> AutoBackupAssetState {
        switch (assetState, event) {
        case (.queued, .stagePrepared):
            return .staged
        case (.staged, .uploadStarted):
            return .uploading
        case (.uploading, .committed):
            return .committed
        case (.queued, .skippedDuplicate),
             (.staged, .skippedDuplicate):
            return .skippedDuplicate
        case (.queued, .failRetained),
             (.staged, .failRetained),
             (.uploading, .failRetained):
            return .failedRetained
        case (.failedRetained, .requeue):
            return .queued
        default:
            throw AutoBackupStateMachineError.invalidAssetTransition(from: assetState, event: event)
        }
    }
}
