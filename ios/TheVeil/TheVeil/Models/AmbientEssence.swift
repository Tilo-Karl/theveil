import Foundation
import simd

struct AmbientEssence: Equatable, Identifiable {
    let id: UUID
    let kind: EssenceKind
    let position: SIMD3<Float>
    let value: Int
    let radius: Float
}
