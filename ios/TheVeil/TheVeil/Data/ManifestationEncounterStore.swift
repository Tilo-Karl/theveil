import Combine
import Foundation

@MainActor
final class ManifestationEncounterStore: ObservableObject {
    @Published private(set) var state: ManifestationEncounterState

    init(state: ManifestationEncounterState = .initial()) {
        self.state = state
    }

    var fieldCharge: Double {
        state.fieldCharge
    }

    var requiredFieldCharge: Double {
        state.requiredFieldCharge
    }

    var fieldChargeFraction: Double {
        guard state.requiredFieldCharge > 0 else {
            return 1
        }
        return min(state.fieldCharge / state.requiredFieldCharge, 1)
    }

    var targetResonance: Double {
        state.targetResonance
    }

    func contributeFieldCharge(_ amount: Double) -> EncounterResonanceResult {
        guard amount > 0, state.phase == .chargingField else {
            return .noEffect
        }

        state.fieldCharge = min(
            state.fieldCharge + amount,
            state.requiredFieldCharge
        )

        guard state.fieldCharge >= state.requiredFieldCharge else {
            return .progressed(
                current: state.fieldCharge,
                required: state.requiredFieldCharge
            )
        }

        state.phase = .resupply
        return .thresholdReached
    }

    func beginManifestation(profile: EntityResonanceProfile) {
        guard state.phase == .resupply else {
            return
        }
        state.phase = .manifested
        state.entityProfile = profile
        state.targetResonance = 0
    }

    func contributeTargetResonance(
        _ amount: Double,
        combinedIntensity: Int
    ) -> EncounterResonanceResult {
        guard
            amount > 0,
            state.phase == .manifested,
            let profile = state.entityProfile,
            combinedIntensity >= profile.threshold
        else {
            return .noEffect
        }

        state.targetResonance = min(
            state.targetResonance + amount,
            profile.stability
        )

        guard state.targetResonance >= profile.stability else {
            return .progressed(
                current: state.targetResonance,
                required: profile.stability
            )
        }

        state.phase = .resolved
        return .thresholdReached
    }

    func decayTargetResonance(_ amount: Double) {
        guard amount > 0, state.phase == .manifested else {
            return
        }
        state.targetResonance = max(0, state.targetResonance - amount)
    }

    func reset(requiredFieldCharge: Double = 5) {
        state = .initial(requiredFieldCharge: requiredFieldCharge)
    }
}
