import simd

struct SurfacePhaseRoute {
    let entryPosition: SIMD3<Float>
    let concealedExitPosition: SIMD3<Float>
    let emergedExitPosition: SIMD3<Float>
}
