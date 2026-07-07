import Foundation
import simd

struct Specter: Identifiable, Equatable {
    let id: UUID
    var position: SIMD3<Float>
    var phase: Float
    var resonanceThreshold: Int
    var spectralStability: Int
    var targetResonance: Double
    var isManifested: Bool

    init(
        id: UUID = UUID(),
        position: SIMD3<Float> = SIMD3<Float>(0, 0, -1),
        phase: Float = 0,
        resonanceThreshold: Int = 1,
        spectralStability: Int = 5,
        targetResonance: Double = 0,
        isManifested: Bool = true
    ) {
        self.id = id
        self.position = position
        self.phase = phase
        self.resonanceThreshold = resonanceThreshold
        self.spectralStability = spectralStability
        self.targetResonance = targetResonance
        self.isManifested = isManifested
    }

    var resonanceProgress: Double {
        guard spectralStability > 0 else { return 0 }
        return min(max(targetResonance / Double(spectralStability), 0), 1)
    }

    var isDestabilized: Bool {
        targetResonance >= Double(spectralStability)
    }
}
