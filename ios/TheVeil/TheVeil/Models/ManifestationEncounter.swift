import Foundation

enum ManifestationEncounterPhase: String, Codable, Equatable, Sendable {
    case chargingField
    case resupply
    case manifested
    case resolved
}

struct EntityResonanceProfile: Codable, Equatable, Sendable {
    let threshold: Int
    let stability: Double

    nonisolated static let lostSoul = EntityResonanceProfile(
        threshold: 1,
        stability: 5
    )
}

struct ManifestationEncounterState: Codable, Equatable, Sendable {
    let id: UUID
    var phase: ManifestationEncounterPhase
    var fieldCharge: Double
    let requiredFieldCharge: Double
    var targetResonance: Double
    var entityProfile: EntityResonanceProfile?

    nonisolated static func initial(
        requiredFieldCharge: Double = 5
    ) -> ManifestationEncounterState {
        ManifestationEncounterState(
            id: UUID(),
            phase: .chargingField,
            fieldCharge: 0,
            requiredFieldCharge: requiredFieldCharge,
            targetResonance: 0,
            entityProfile: nil
        )
    }
}

enum EncounterResonanceResult: Equatable {
    case noEffect
    case progressed(current: Double, required: Double)
    case thresholdReached
}
