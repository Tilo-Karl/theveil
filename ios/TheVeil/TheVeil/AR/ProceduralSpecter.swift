import RealityKit
import simd

@MainActor
enum ProceduralSpecter {
    /// A deliberately flat, camera-facing canvas.
    /// The Specter is defined by its face silhouette in the shader, not by a fake 3D blob.
    static func makeFacePlane() throws -> MeshResource {
        let width: Float = 1.10
        let height: Float = 1.55

        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-width * 0.5, -height * 0.5, 0),
            SIMD3<Float>( width * 0.5, -height * 0.5, 0),
            SIMD3<Float>(-width * 0.5,  height * 0.5, 0),
            SIMD3<Float>( width * 0.5,  height * 0.5, 0)
        ]

        let normals = Array(
            repeating: SIMD3<Float>(0, 0, 1),
            count: positions.count
        )

        let textureCoordinates: [SIMD2<Float>] = [
            SIMD2<Float>(0, 1),
            SIMD2<Float>(1, 1),
            SIMD2<Float>(0, 0),
            SIMD2<Float>(1, 0)
        ]

        let indices: [UInt32] = [
            0, 1, 2,
            2, 1, 3
        ]

        var descriptor = MeshDescriptor(name: "specter-face-plane")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles(indices)

        return try MeshResource.generate(from: [descriptor])
    }
}
