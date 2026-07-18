import Metal
import RealityKit
import UIKit

@MainActor
final class EctoMaterialFactory {
    private let outerShellMaterial: CustomMaterial?
    private let innerGelMaterial: CustomMaterial?

    init() {
        guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else {
            outerShellMaterial = nil
            innerGelMaterial = nil
            return
        }

        outerShellMaterial = Self.makeOuterShellMaterial(library: library)
        innerGelMaterial = Self.makeInnerGelMaterial(library: library)
    }

    func makeOuterShellMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        guard var material = outerShellMaterial else {
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

    func makeInnerGelMaterial(
        variant: EctoVariant,
        phase: Float,
        visibility: Float = 1,
        reactivity: Float = 0
    ) -> CustomMaterial? {
        guard var material = innerGelMaterial else {
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

    func makeOuterShellFallbackMaterial(variant: EctoVariant, alpha: CGFloat = 0.68) -> UnlitMaterial {
        var material = UnlitMaterial(color: outerShellColor(for: variant, alpha: alpha))
        material.blending = .transparent(opacity: .init(scale: 1))
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    func makeInnerGelFallbackMaterial(variant: EctoVariant, alpha: CGFloat = 0.32) -> UnlitMaterial {
        var material = UnlitMaterial(color: innerGelColor(for: variant, alpha: alpha))
        material.blending = .transparent(opacity: .init(scale: 1))
        material.readsDepth = true
        material.writesDepth = false
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

    private static func makeOuterShellMaterial(library: any MTLLibrary) -> CustomMaterial? {
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
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private static func makeInnerGelMaterial(library: any MTLLibrary) -> CustomMaterial? {
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
        material.faceCulling = .none
        material.readsDepth = true
        material.writesDepth = false
        return material
    }

    private func outerShellColor(for variant: EctoVariant, alpha: CGFloat) -> UIColor {
        switch variant {
        case .lime:
            return UIColor(red: 0.18, green: 0.98, blue: 0.46, alpha: alpha)
        case .cyan:
            return UIColor(red: 0.12, green: 0.92, blue: 1, alpha: alpha)
        case .amethyst:
            return UIColor(red: 0.58, green: 0.34, blue: 1, alpha: alpha)
        case .ember:
            return UIColor(red: 0.55, green: 0.92, blue: 0.34, alpha: alpha)
        case .golden:
            return UIColor(red: 0.42, green: 1.00, blue: 0.36, alpha: alpha)
        }
    }

    private func innerGelColor(for variant: EctoVariant, alpha: CGFloat) -> UIColor {
        switch variant {
        case .lime:
            return UIColor(red: 0.32, green: 1, blue: 0.54, alpha: alpha)
        case .cyan:
            return UIColor(red: 0.28, green: 1, blue: 1, alpha: alpha)
        case .amethyst:
            return UIColor(red: 0.82, green: 0.48, blue: 1, alpha: alpha)
        case .ember:
            return UIColor(red: 0.72, green: 1, blue: 0.36, alpha: alpha)
        case .golden:
            return UIColor(red: 0.74, green: 1, blue: 0.42, alpha: alpha)
        }
    }

    private func coreColor(for variant: EctoVariant, alpha: CGFloat) -> UIColor {
        switch variant {
        case .lime:
            return UIColor(red: 0.76, green: 1, blue: 0.44, alpha: alpha)
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
