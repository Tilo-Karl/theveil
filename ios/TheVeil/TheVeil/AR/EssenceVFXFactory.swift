import CoreGraphics
import Metal
import RealityKit
import UIKit

@MainActor
final class EssenceVFXFactory {
    private let library: (any MTLLibrary)?
    private let coreTexture = EssenceCoreTextureFactory.makeTexture()

    init() {
        library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()
    }

    func make(radius: Float, phase: Float) -> EssenceVFX? {
        guard let library else {
            return nil
        }

        let plasmaMesh = MeshResource.generateSphere(radius: radius * 0.9)
        let shellSettings: [(scale: Float, displacement: Float, intensity: Float, opacity: Float)] = [
            (0.78, radius * 0.08, 3.6, 1),
            (1.0, radius * 0.13, 2.55, 0.76),
            (1.28, radius * 0.19, 1.65, 0.5),
            (1.62, radius * 0.27, 0.9, 0.26)
        ]
        let plasmaShells = shellSettings.enumerated().compactMap { index, settings in
            makePlasmaShell(
                mesh: plasmaMesh,
                scale: settings.scale,
                displacement: settings.displacement,
                intensity: settings.intensity,
                opacity: settings.opacity,
                phase: phase + Float(index) * 0.29,
                library: library
            )
        }

        guard
            plasmaShells.count == shellSettings.count,
            let core = makeCore(radius: radius, diameterScale: 1.22, opacity: 1),
            let coreHalo = makeCore(radius: radius, diameterScale: 2.45, opacity: 0.24),
            let ribbon = try? ProceduralEssenceRibbon(
                radius: radius,
                phase: phase,
                library: library
            )
        else {
            return nil
        }

        return EssenceVFX(
            core: core,
            coreHalo: coreHalo,
            plasmaShells: plasmaShells,
            ribbon: ribbon,
            phase: phase
        )
    }

    private func makePlasmaShell(
        mesh: MeshResource,
        scale: Float,
        displacement: Float,
        intensity: Float,
        opacity: Float,
        phase: Float,
        library: any MTLLibrary
    ) -> ModelEntity? {
        let surface = CustomMaterial.SurfaceShader(
            named: "essencePlasmaSurface",
            in: library
        )
        let geometry = CustomMaterial.GeometryModifier(
            named: "essencePlasmaGeometry",
            in: library
        )
        guard var material = try? CustomMaterial(
            surfaceShader: surface,
            geometryModifier: geometry,
            lightingModel: .unlit
        ) else {
            return nil
        }

        material.custom.value = SIMD4<Float>(displacement, intensity, phase, opacity)
        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(repeating: scale)
        return entity
    }

    private func makeCore(
        radius: Float,
        diameterScale: Float,
        opacity: Float
    ) -> ModelEntity? {
        guard let coreTexture else {
            return nil
        }

        var material = UnlitMaterial(texture: coreTexture)
        material.blending = .transparent(opacity: .init(scale: opacity))
        material.readsDepth = true
        material.writesDepth = false

        let diameter = radius * diameterScale
        let core = ModelEntity(
            mesh: .generatePlane(width: diameter, height: diameter),
            materials: [material]
        )
        core.components.set(BillboardComponent())
        return core
    }
}

@MainActor
final class EssenceVFX {
    let core: ModelEntity
    let coreHalo: ModelEntity
    let plasmaShells: [ModelEntity]
    let ribbon: ProceduralEssenceRibbon
    let entities: [Entity]

    private let phase: Float

    init(
        core: ModelEntity,
        coreHalo: ModelEntity,
        plasmaShells: [ModelEntity],
        ribbon: ProceduralEssenceRibbon,
        phase: Float
    ) {
        self.core = core
        self.coreHalo = coreHalo
        self.plasmaShells = plasmaShells
        self.ribbon = ribbon
        self.phase = phase
        self.entities = [coreHalo] + plasmaShells + [ribbon.entity, core]
    }

    func update(at time: Float) {
        let pulse = 0.9 + sin(time * 1.75 + phase) * 0.1
        core.scale = SIMD3<Float>(repeating: pulse)
        let haloPulse = 0.96 + sin(time * 1.2 + phase + 0.7) * 0.08
        coreHalo.scale = SIMD3<Float>(repeating: haloPulse)

        for (index, shell) in plasmaShells.enumerated() {
            let direction: Float = index.isMultiple(of: 2) ? 1 : -1
            shell.orientation = simd_quatf(
                angle: direction * time * (0.08 + Float(index) * 0.025),
                axis: simd_normalize(SIMD3<Float>(0.3 + Float(index) * 0.2, 1, 0.18))
            )
        }

        ribbon.update(at: time + phase)
    }
}

private enum EssenceCoreTextureFactory {
    static func makeTexture() -> TextureResource? {
        let size = 192
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let center = CGPoint(x: size / 2, y: size / 2)
        let colors = [
            UIColor.white.cgColor,
            UIColor(red: 0.55, green: 0.9, blue: 1, alpha: 0.95).cgColor,
            UIColor(red: 0.28, green: 0.34, blue: 1, alpha: 0.42).cgColor,
            UIColor.clear.cgColor
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0, 0.13, 0.42, 1]
        ) else {
            return nil
        }

        context.setBlendMode(.plusLighter)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(size) * 0.48,
            options: []
        )

        context.setStrokeColor(UIColor(red: 0.72, green: 0.94, blue: 1, alpha: 0.78).cgColor)
        context.setLineCap(.round)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: center.x, y: 6))
        context.addLine(to: CGPoint(x: center.x, y: CGFloat(size - 6)))
        context.strokePath()
        context.move(to: CGPoint(x: 6, y: center.y))
        context.addLine(to: CGPoint(x: CGFloat(size - 6), y: center.y))
        context.strokePath()

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))

        guard let image = context.makeImage() else {
            return nil
        }

        return try? TextureResource(
            image: image,
            withName: "veil-essence-core",
            options: .init(semantic: .color)
        )
    }
}
