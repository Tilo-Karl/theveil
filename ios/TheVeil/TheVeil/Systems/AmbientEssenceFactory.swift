import Foundation
import simd

struct AmbientEssenceFactory {
    func makeInitialField() -> [AmbientEssence] {
        [
            makeEssence(kind: .wisp, position: SIMD3<Float>(-0.42, 0.10, -1.15), value: 1),
            makeEssence(kind: .echo, position: SIMD3<Float>(0.08, -0.08, -1.35), value: 1),
            makeEssence(kind: .ember, position: SIMD3<Float>(0.48, 0.18, -1.55), value: 1),
            makeEssence(kind: .wisp, position: SIMD3<Float>(-0.10, 0.34, -1.85), value: 1),
            makeEssence(kind: .echo, position: SIMD3<Float>(0.36, -0.26, -2.05), value: 1)
        ]
    }

    private func makeEssence(kind: EssenceKind, position: SIMD3<Float>, value: Int) -> AmbientEssence {
        AmbientEssence(
            id: UUID(),
            kind: kind,
            position: position,
            value: value,
            radius: 0.055
        )
    }
}
