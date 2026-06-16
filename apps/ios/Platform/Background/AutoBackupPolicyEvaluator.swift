import Foundation
import Network
import ICherriProtocol

struct AutoBackupRuntimeSnapshot: Sendable, Equatable {
    var batteryLevelPercent: Int
    var isWiFiEnabled: Bool
    var isLowPowerModeEnabled: Bool
    var thermalState: ProcessInfo.ThermalState
    var hasPairedReceiver: Bool

    static let previewEligible = AutoBackupRuntimeSnapshot(
        batteryLevelPercent: 100,
        isWiFiEnabled: true,
        isLowPowerModeEnabled: false,
        thermalState: .nominal,
        hasPairedReceiver: true
    )
}

enum AutoBackupEligibilityBlockReason: String, Codable, Sendable, Equatable {
    case disabled
    case batteryBelowMinimum = "battery_below_minimum"
    case wiFiUnavailable = "wifi_unavailable"
    case receiverUnavailable = "receiver_unavailable"
    case lowPowerMode = "low_power_mode"
    case thermal = "thermal"
}

struct AutoBackupEligibilityResult: Sendable, Equatable {
    let isEligible: Bool
    let reason: AutoBackupEligibilityBlockReason?

    static let eligible = AutoBackupEligibilityResult(isEligible: true, reason: nil)
}

struct AutoBackupPolicyEvaluator {
    func evaluate(
        policy: AutoBackupPolicy,
        runtimeSnapshot: AutoBackupRuntimeSnapshot
    ) -> AutoBackupEligibilityResult {
        guard policy.isEnabled else {
            return .init(isEligible: false, reason: .disabled)
        }

        guard runtimeSnapshot.hasPairedReceiver else {
            return .init(isEligible: false, reason: .receiverUnavailable)
        }

        guard runtimeSnapshot.batteryLevelPercent >= policy.minimumBatteryPercent else {
            return .init(isEligible: false, reason: .batteryBelowMinimum)
        }

        if policy.requiresWiFiEnabled, !runtimeSnapshot.isWiFiEnabled {
            return .init(isEligible: false, reason: .wiFiUnavailable)
        }

        if policy.blocksOnLowPowerMode, runtimeSnapshot.isLowPowerModeEnabled {
            return .init(isEligible: false, reason: .lowPowerMode)
        }

        if runtimeSnapshot.thermalState.meetsOrExceeds(policy.pauseThermalThreshold) {
            return .init(isEligible: false, reason: .thermal)
        }

        return .eligible
    }
}

private extension ProcessInfo.ThermalState {
    func meetsOrExceeds(_ threshold: AutoBackupThermalThreshold) -> Bool {
        switch threshold {
        case .serious:
            return self == .serious || self == .critical
        case .critical:
            return self == .critical
        }
    }
}
