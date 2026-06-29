import ARKit
import CoreVideo
import MetalKit
import RealityKit
import UIKit

@MainActor
final class SpectralARContainerView: UIView {
    let arView: ARView

    private let cameraView: SpectralCameraView

    init(postProcessor: VeilCameraPostProcessor) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is required for the spectral camera")
        }

        arView = ARView(
            frame: .zero,
            cameraMode: .ar,
            automaticallyConfigureSession: false
        )
        cameraView = SpectralCameraView(
            frame: .zero,
            device: device,
            postProcessor: postProcessor
        )

        super.init(frame: .zero)

        backgroundColor = .black
        cameraView.session = arView.session

        arView.isOpaque = false
        arView.layer.isOpaque = false
        arView.backgroundColor = .clear
        arView.environment.background = .color(.clear)

        addSubview(cameraView)
        addSubview(arView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cameraView.frame = bounds
        arView.frame = bounds
    }

    func stop() {
        cameraView.isPaused = true
    }
}

@MainActor
private final class SpectralCameraView: MTKView, MTKViewDelegate {
    weak var session: ARSession?

    private let commandQueue: any MTLCommandQueue
    private let postProcessor: VeilCameraPostProcessor
    private var textureCache: CVMetalTextureCache?

    init(
        frame: CGRect,
        device: any MTLDevice,
        postProcessor: VeilCameraPostProcessor
    ) {
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Unable to create the spectral camera command queue")
        }

        self.commandQueue = commandQueue
        self.postProcessor = postProcessor
        super.init(frame: frame, device: device)

        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(0, 0, 0, 1)
        framebufferOnly = false
        enableSetNeedsDisplay = false
        isPaused = false
        preferredFramesPerSecond = 60
        delegate = self

        postProcessor.prepare(with: device)
        CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            bounds.width > 0,
            bounds.height > 0,
            let frame = session?.currentFrame,
            let textureCache,
            let drawable = currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let textures = makeCameraTextures(
                from: frame.capturedImage,
                cache: textureCache
            )
        else {
            return
        }

        let orientation = window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let viewToImage = frame.displayTransform(
            for: orientation,
            viewportSize: bounds.size
        ).inverted()

        postProcessor.encodeCameraFrame(
            luminanceTexture: textures.luminance,
            chromaTexture: textures.chroma,
            targetTexture: drawable.texture,
            viewToImageTransform: viewToImage,
            time: CACurrentMediaTime(),
            commandBuffer: commandBuffer
        )

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeCameraTextures(
        from pixelBuffer: CVPixelBuffer,
        cache: CVMetalTextureCache
    ) -> (luminance: any MTLTexture, chroma: any MTLTexture)? {
        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
            return nil
        }

        var luminanceReference: CVMetalTexture?
        let luminanceStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .r8Unorm,
            CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
            CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
            0,
            &luminanceReference
        )

        var chromaReference: CVMetalTexture?
        let chromaStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .rg8Unorm,
            CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
            CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
            1,
            &chromaReference
        )

        guard
            luminanceStatus == kCVReturnSuccess,
            chromaStatus == kCVReturnSuccess,
            let luminanceReference,
            let chromaReference,
            let luminance = CVMetalTextureGetTexture(luminanceReference),
            let chroma = CVMetalTextureGetTexture(chromaReference)
        else {
            return nil
        }

        return (luminance, chroma)
    }
}
