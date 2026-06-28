import Foundation
import simd

struct AmbientEssenceFactory {
    func makeInitialField() -> [AmbientEssence] {
        [
            makeEssence(position: SIMD3<Float>(0.12, -0.12, -0.82)),
            makeEssence(position: SIMD3<Float>(-0.72, 0.16, -1.20)),
            makeEssence(position: SIMD3<Float>(0.78, -0.22, -1.48)),
            makeEssence(position: SIMD3<Float>(-0.92, 0.46, -1.72)),
            makeEssence(position: SIMD3<Float>(0.84, 0.52, -2.02))
        ]
    }

    private func makeEssence(position: SIMD3<Float>) -> AmbientEssence {
        AmbientEssence(
            id: UUID(),
            position: position,
            value: 1,
            radius: 0.082
        )
    }
}
