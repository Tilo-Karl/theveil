import simd

struct SurfacePhaseRoute {
    let entryPosition: SIMD3<Float>
    let entryNormal: SIMD3<Float>
    let concealedExitPosition: SIMD3<Float>
    let emergedExitPosition: SIMD3<Float>
    let exitNormal: SIMD3<Float>
}
