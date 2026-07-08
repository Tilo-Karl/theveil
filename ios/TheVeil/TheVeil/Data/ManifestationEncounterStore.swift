import Combine
import Foundation

@MainActor
final class ManifestationEncounterStore: ObservableObject {
    @Published private(set) var state: ManifestationEncounterState
    private let completionTolerance = 0.001

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

    var isFieldReadyForManifestation: Bool {
        state.phase == .resupply
            || state.fieldCharge + completionTolerance >= state.requiredFieldCharge
    }

    var ectoplasmicDamage: Double {
        state.ectoplasmicDamage
    }

    func contributeFieldCharge(_ amount: Double) -> EncounterResonanceResult {
        guard amount > 0, state.phase == .chargingField else {
            return .noEffect
        }

        let nextFieldCharge = min(
            state.fieldCharge + amount,
            state.requiredFieldCharge
        )
        state.fieldCharge = nextFieldCharge

        guard isFieldReadyForManifestation else {
            return .progressed(
                current: state.fieldCharge,
                required: state.requiredFieldCharge
            )
        }

        state.fieldCharge = state.requiredFieldCharge
        state.phase = .resupply
        return .thresholdReached
    }

    func completeFieldChargeIfReady() -> Bool {
        guard state.phase == .chargingField, isFieldReadyForManifestation else {
            return state.phase == .resupply
        }

        state.fieldCharge = state.requiredFieldCharge
        state.phase = .resupply
        return true
    }

    func beginManifestation(profile: EntityResonanceProfile) {
        guard state.phase == .resupply else {
            return
        }
        state.phase = .manifested
        state.entityProfile = profile
        state.ectoplasmicDamage = 0
    }

    func applyResonanceOutput(
        output: Double,
        pulseFraction: Double
    ) -> EncounterResonanceResult {
        let clampedFraction = min(max(pulseFraction, 0), 1)
        guard
            clampedFraction > 0,
            state.phase == .manifested,
            let profile = state.entityProfile
        else {
            return .noEffect
        }

        let damagePerPulse = max(0, output - profile.resonanceResistance)
        guard damagePerPulse > 0 else {
            return .insufficientOutput(
                output: output,
                resistance: profile.resonanceResistance
            )
        }

        state.ectoplasmicDamage = min(
            state.ectoplasmicDamage + damagePerPulse * clampedFraction,
            profile.ectoplasmicIntegrity
        )

        guard state.ectoplasmicDamage >= profile.ectoplasmicIntegrity else {
            return .progressed(
                current: state.ectoplasmicDamage,
                required: profile.ectoplasmicIntegrity
            )
        }

        state.phase = .resolved
        return .thresholdReached
    }

    func decayEctoplasmicDamage(_ amount: Double) {
        guard amount > 0, state.phase == .manifested else {
            return
        }
        state.ectoplasmicDamage = max(0, state.ectoplasmicDamage - amount)
    }

    func endManifestationAsEscaped() {
        guard state.phase == .manifested else {
            return
        }
        state.phase = .escaped
    }

    func reset(requiredFieldCharge: Double = 5) {
        state = .initial(requiredFieldCharge: requiredFieldCharge)
    }
}
