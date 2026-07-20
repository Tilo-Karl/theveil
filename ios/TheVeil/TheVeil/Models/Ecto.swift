import Foundation
import simd

struct Ecto: Equatable, Identifiable {
    static let ectoplasmicIntegrity: Double = 6
    static let scannerZapDamage: Double = 2

    let id: UUID
    let position: SIMD3<Float>
    let variant: EctoVariant
    let essenceValue: Int
    let radius: Float

    init(
        id: UUID = UUID(),
        position: SIMD3<Float>,
        variant: EctoVariant = .cyan,
        essenceValue: Int = 1,
        radius: Float = 0.18
    ) {
        self.id = id
        self.position = position
        self.variant = variant
        self.essenceValue = essenceValue
        self.radius = radius
    }
}

enum EctoState: String {
    case idle
    case preparingToJump
    case airborne
    case landing
    case startled
    case captured
}

enum EctoVariant: Int, CaseIterable {
    case lime
    case cyan
    case amethyst
    case ember
    case golden
}

enum EctoResonanceResult: Equatable {
    case noEffect
    case progressed(current: Double, required: Double)
    case thresholdReached(Ecto)
}
