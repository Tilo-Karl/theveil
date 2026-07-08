import Foundation
import simd

struct Specter: Identifiable, Equatable {
    let id: UUID
    var position: SIMD3<Float>
    var phase: Float
    var isManifested: Bool

    init(
        id: UUID = UUID(),
        position: SIMD3<Float> = SIMD3<Float>(0, 0, -1),
        phase: Float = 0,
        isManifested: Bool = true
    ) {
        self.id = id
        self.position = position
        self.phase = phase
        self.isManifested = isManifested
    }
}
