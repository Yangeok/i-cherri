import Foundation
import Testing
import ICherriProtocol
@testable import iCherri_ios

struct AutoBackupPolicyEvaluatorTests {

    @Test("Given Wi-Fi policy when Wi-Fi is unavailable then eligibility is blocked")
    func blocksWhenWiFiUnavailable() {
        let evaluator = AutoBackupPolicyEvaluator()
        let result = evaluator.evaluate(
            policy: AutoBackupPolicy(isEnabled: true),
            runtimeSnapshot: .init(
                batteryLevelPercent: 100,
                isWiFiEnabled: false,
                isLowPowerModeEnabled: false,
                thermalState: .nominal,
                hasPairedReceiver: true
            )
        )

        #expect(result == .init(isEligible: false, reason: .wiFiUnavailable))
    }

    @Test("Given a thermal pause threshold when device is serious then eligibility is blocked for thermal reasons")
    func blocksWhenThermalStateIsSerious() {
        let evaluator = AutoBackupPolicyEvaluator()
        let result = evaluator.evaluate(
            policy: AutoBackupPolicy(isEnabled: true),
            runtimeSnapshot: .init(
                batteryLevelPercent: 100,
                isWiFiEnabled: true,
                isLowPowerModeEnabled: false,
                thermalState: .serious,
                hasPairedReceiver: true
            )
        )

        #expect(result == .init(isEligible: false, reason: .thermal))
    }
}
