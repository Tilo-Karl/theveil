import Foundation

enum ManifestationEncounterPhase: String, Codable, Equatable, Sendable {
    case chargingField
    case resupply
    case manifested
    case resolved
    case escaped
}

struct EntityResonanceProfile: Codable, Equatable, Sendable {
    let resonanceResistance: Double
    let ectoplasmicIntegrity: Double

    nonisolated static let lostSoul = EntityResonanceProfile(
        resonanceResistance: 0,
        ectoplasmicIntegrity: 5
    )

    nonisolated static let minorSpecter = EntityResonanceProfile(
        resonanceResistance: 0,
        ectoplasmicIntegrity: 10
    )
}

struct ManifestationEncounterState: Codable, Equatable, Sendable {
    let id: UUID
    var phase: ManifestationEncounterPhase
    var fieldCharge: Double
    let requiredFieldCharge: Double
    var ectoplasmicDamage: Double
    var entityProfile: EntityResonanceProfile?

    nonisolated static func initial(
        requiredFieldCharge: Double = 5
    ) -> ManifestationEncounterState {
        ManifestationEncounterState(
            id: UUID(),
            phase: .chargingField,
            fieldCharge: 0,
            requiredFieldCharge: requiredFieldCharge,
            ectoplasmicDamage: 0,
            entityProfile: nil
        )
    }
}

enum EncounterResonanceResult: Equatable {
    case noEffect
    case progressed(current: Double, required: Double)
    case thresholdReached
    case insufficientOutput(output: Double, resistance: Double)
}
