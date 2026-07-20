import Metal
import RealityKit
import UIKit

@MainActor
final class EctoMaterialFactory {
    private let outerShellMaterial: CustomMaterial?
    private let innerGelMaterial: CustomMaterial?
    private let lobeMembraneMaterial: CustomMaterial?
    private let bubbleMaterial: CustomMaterial?
    private let corneaMaterial: CustomMaterial?
    private let bodyOnlyTexture: TextureResource

    init() {
        guard let bodyOnlyTextureURL = Bundle.main.url(
            forResource: "EctoBodyOnlyColor",
            withExtension: "png"
        ) else {
            preconditionFailure("Missing EctoBodyOnlyColor.png in the app bundle")
        }
        bodyOnlyTexture = try! TextureResource.load(contentsOf: bodyOnlyTextureURL)

        guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else {
            preconditionFailure("Missing default Metal library for Ecto custom materials")
        }

        guard let outerShellMaterial = Self.makeOuterShellMaterial(
            library: library,
            bodyOnlyTexture: bodyOnlyTexture
        ) else {
            preconditionFailure("Failed to create ectoOuterShellSurface material")
        }

        guard let innerGelMaterial = Self.makeInnerGelMaterial(
            library: library,
            bodyOnlyTexture: bodyOnlyTexture
        ) else {
            preconditionFailure("Failed to create ectoInnerGelSurface material")
        }

        guard let lobeMembraneMaterial = Self.makeLobeMembraneMaterial(library: library) else {
            preconditionFailure("Failed to create ectoLobeMembraneSurface material")
        }

        guard let bubbleMaterial = Self.makeBubbleMaterial(library: library) else {
            preconditionFailure("Failed to create ectoBubbleSurface material")
        }

        guard let corneaMaterial = Self.makeCorneaMaterial(library: library) else {
            preconditionFailure("Failed to create ectoCorneaSurface material")
        }

        self.outerShellMaterial = outerShellMaterial
        self.innerGelMaterial = innerGelMaterial
        self.lobeMembraneMaterial = lobeMembraneMaterial
        self.bubbleMaterial = bubbleMaterial
        self.corneaMaterial = corneaMaterial
    }

    func makeBodyTextureProofMaterial() -> UnlitMaterial {
        var material = UnlitMaterial(texture: bodyOnlyTexture)
        material.readsDepth = true
        material.writesDepth = true
        return material
    }

    func makeOuterShellMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        configuredMaterial(
            outerShellMaterial,
            variant: variant,
            phase: phase,
            visibility: visibility,
            reactivity: reactivity
        )
    }

    func makeInnerGelMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        configuredMaterial(
            innerGelMaterial,
            variant: variant,
            phase: phase,
            visibility: visibility,
            reactivity: reactivity
        )
    }

    func makeLobeMembraneMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        configuredMaterial(
            lobeMembraneMaterial,
            variant: variant,
            phase: phase,
            visibility: visibility,
            reactivity: reactivity
        )
    }

    func makeBubbleMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        configuredMaterial(
            bubbleMaterial,
            variant: variant,
            phase: phase,
            visibility: visibility,
            reactivity: reactivity
        )
    }

    func makeCorneaMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        configuredMaterial(
            corneaMaterial,
            variant: variant,
            phase: phase,
            visibility: visibility,
            reactivity: reactivity
        )
    }

    private func configuredMaterial(
        _ source: CustomMaterial?,
        variant: EctoVariant,
        phase: Float,
        visibility: Float,
        reactivity: Float
    ) -> CustomMaterial? {
        guard var material = source else {
            return nil
        }

        material.custom.value = SIMD4<Float>(
            phase,
            visibility,
            reactivity,
            Float(variant.rawValue)
        )
        return material
    }

    func makeCoreMaterial(variant: EctoVariant, intensity: CGFloat = 1) -> UnlitMaterial {
        var material = UnlitMaterial(color: coreColor(for: variant, alpha: intensity))
        material.blending = .transparent(opacity: .init(scale: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    func makeContactShadowMaterial(variant: EctoVariant) -> UnlitMaterial {
        var material = UnlitMaterial(color: shadowColor(for: variant))
        material.blending = .transparent(opacity: .init(scale: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    func makeEyeMaterial(variant: EctoVariant) -> UnlitMaterial {
        var material = UnlitMaterial(color: eyeColor(for: variant))
        material.blending = .transparent(opacity: .init(scale: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    func makeMouthMaterial() -> UnlitMaterial {
        var material = UnlitMaterial(color: UIColor.black.withAlphaComponent(0.82))
        material.blending = .transparent(opacity: .init(scale: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    func makeDropletTexture(variant: EctoVariant) -> TextureResource? {
        SpectralParticleTextureFactory.makeTexture(
            color: dropletColor(for: variant),
            name: "ecto-droplet-\(variant.rawValue)"
        )
    }

    private static func makeOuterShellMaterial(
        library: any MTLLibrary,
        bodyOnlyTexture: TextureResource
    ) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(named: "ectoOuterShellSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "ectoOuterShellGeometry", in: library)
        guard
            var material = try? CustomMaterial(
                surfaceShader: surface,
                geometryModifier: geometry,
                lightingModel: .clearcoat
            )
        else {
            return nil
        }

        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .back
        material.readsDepth = true
        material.writesDepth = false
        material.custom.texture = .init(bodyOnlyTexture)
        return material
    }

    private static func makeInnerGelMaterial(
        library: any MTLLibrary,
        bodyOnlyTexture: TextureResource
    ) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(named: "ectoInnerGelSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "ectoInnerGelGeometry", in: library)
        guard
            var material = try? CustomMaterial(
                surfaceShader: surface,
                geometryModifier: geometry,
                lightingModel: .lit
            )
        else {
            return nil
        }

        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .back
        material.readsDepth = true
        material.writesDepth = false
        material.custom.texture = .init(bodyOnlyTexture)
        return material
    }

    private static func makeLobeMembraneMaterial(library: any MTLLibrary) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(named: "ectoLobeMembraneSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "ectoOuterShellGeometry", in: library)
        guard
            var material = try? CustomMaterial(
                surfaceShader: surface,
                geometryModifier: geometry,
                lightingModel: .clearcoat
            )
        else {
            return nil
        }

        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .back
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func makeBubbleMaterial(library: any MTLLibrary) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(named: "ectoBubbleSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "ectoOuterShellGeometry", in: library)
        guard
            var material = try? CustomMaterial(
                surfaceShader: surface,
                geometryModifier: geometry,
                lightingModel: .clearcoat
            )
        else {
            return nil
        }

        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .back
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func makeCorneaMaterial(library: any MTLLibrary) -> CustomMaterial? {
        let surface = CustomMaterial.SurfaceShader(named: "ectoCorneaSurface", in: library)
        let geometry = CustomMaterial.GeometryModifier(named: "ectoOuterShellGeometry", in: library)
        guard
            var material = try? CustomMaterial(
                surfaceShader: surface,
                geometryModifier: geometry,
                lightingModel: .clearcoat
            )
        else {
            return nil
        }

        material.blending = .transparent(opacity: .init(scale: 1))
        material.faceCulling = .back
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private func coreColor(for variant: EctoVariant, alpha: CGFloat) -> UIColor {
        switch variant {
        case .lime:
            return UIColor(red: 0.96, green: 1.00, blue: 0.24, alpha: alpha)
        case .cyan:
            return UIColor(red: 0.62, green: 1, blue: 1, alpha: alpha)
        case .amethyst:
            return UIColor(red: 0.94, green: 0.55, blue: 1, alpha: alpha)
        case .ember:
            return UIColor(red: 0.86, green: 1, blue: 0.36, alpha: alpha)
        case .golden:
            return UIColor(red: 0.82, green: 1, blue: 0.42, alpha: alpha)
        }
    }

    private func shadowColor(for variant: EctoVariant) -> UIColor {
        switch variant {
        case .ember, .golden:
            return UIColor(red: 0.28, green: 0.12, blue: 0.05, alpha: 0.22)
        case .amethyst:
            return UIColor(red: 0.22, green: 0.04, blue: 0.36, alpha: 0.24)
        default:
            return UIColor(red: 0.02, green: 0.14, blue: 0.18, alpha: 0.22)
        }
    }

    private func eyeColor(for variant: EctoVariant) -> UIColor {
        switch variant {
        case .ember, .golden:
            return UIColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 0.92)
        default:
            return UIColor(red: 0.01, green: 0.04, blue: 0.06, alpha: 0.92)
        }
    }

    private func dropletColor(for variant: EctoVariant) -> UIColor {
        switch variant {
        case .lime:
            return UIColor(red: 0.44, green: 1, blue: 0.28, alpha: 0.75)
        case .cyan:
            return UIColor(red: 0.25, green: 0.9, blue: 1, alpha: 0.75)
        case .amethyst:
            return UIColor(red: 0.78, green: 0.32, blue: 1, alpha: 0.75)
        case .ember:
            return UIColor(red: 0.82, green: 1, blue: 0.22, alpha: 0.75)
        case .golden:
            return UIColor(red: 0.74, green: 1, blue: 0.24, alpha: 0.75)
        }
    }
}
