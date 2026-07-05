import CoreGraphics
import RealityKit
import UIKit

enum SpectralParticleTextureFactory {
    static func makeTexture(color: UIColor, name: String = "veil-particle-glow") -> TextureResource? {
        let size = 64
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

        let transparent = color.withAlphaComponent(0).cgColor
        let colors = [
            color.cgColor,
            color.withAlphaComponent(0.5).cgColor,
            transparent
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: [0, 0.28, 1]
        ) else {
            return nil
        }

        let center = CGPoint(x: size / 2, y: size / 2)
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(size) / 2,
            options: [.drawsAfterEndLocation]
        )

        guard let image = context.makeImage() else {
            return nil
        }

        return try? TextureResource(
            image: image,
            withName: name,
            options: .init(semantic: .color)
        )
    }
}
