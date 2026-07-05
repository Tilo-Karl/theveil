import Foundation
import simd

struct AmbientEssenceFactory {
    func makeInitialField() -> [AmbientEssence] {
        [
            makeEssence(position: SIMD3<Float>(0.12, -0.12, -0.82)),
            makeEssence(position: SIMD3<Float>(-0.72, 0.16, -1.20)),
            makeEssence(position: SIMD3<Float>(0.78, -0.22, -1.48)),
            makeEssence(position: SIMD3<Float>(-0.92, 0.46, -1.72)),
            makeEssence(position: SIMD3<Float>(0.84, 0.52, -2.02)),
            makeEssence(position: SIMD3<Float>(-0.34, -0.38, -1.58)),
            makeEssence(position: SIMD3<Float>(0.44, 0.28, -1.82)),
            makeEssence(position: SIMD3<Float>(-0.64, -0.08, -2.16))
        ]
    }

    func makeResupplyField(
        cameraPosition: SIMD3<Float>,
        cameraForward: SIMD3<Float>
    ) -> [AmbientEssence] {
        var forward = SIMD3<Float>(cameraForward.x, 0, cameraForward.z)
        if simd_length_squared(forward) < 0.000_001 {
            forward = SIMD3<Float>(0, 0, -1)
        } else {
            forward = simd_normalize(forward)
        }
        let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))

        return [
            makeEssence(
                position: cameraPosition + forward * 0.92 - right * 0.42
                    + SIMD3<Float>(0, 0.08, 0)
            ),
            makeEssence(
                position: cameraPosition + forward * 1.08 + right * 0.38
                    + SIMD3<Float>(0, 0.24, 0)
            ),
            makeEssence(
                position: cameraPosition + forward * 0.82 + right * 0.12
                    + SIMD3<Float>(0, -0.28, 0)
            )
        ]
    }

    private func makeEssence(position: SIMD3<Float>) -> AmbientEssence {
        AmbientEssence(
            id: UUID(),
            position: position,
            value: 1,
            radius: 0.064
        )
    }
}
