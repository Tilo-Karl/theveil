import CoreGraphics
import Metal

final class VeilCameraPostProcessor {
    private var pipelineState: MTLComputePipelineState?
    private var essenceEffects = Array(repeating: SIMD4<Float>.zero, count: 5)
    private var essenceEffectCount: UInt32 = 0
    private var lensIntensity: Float = 0

    func setLensIntensity(_ intensity: Float) {
        lensIntensity = min(max(intensity, 0), 1)
    }

    func updateEssenceEffects(_ effects: [SIMD4<Float>]) {
        essenceEffectCount = UInt32(min(effects.count, essenceEffects.count))

        for index in essenceEffects.indices {
            essenceEffects[index] = index < effects.count ? effects[index] : .zero
        }
    }

    func prepare(with device: any MTLDevice) {
        guard
            let library = device.makeDefaultLibrary(),
            let function = library.makeFunction(name: "veilCameraColorGrade")
        else {
            return
        }

        pipelineState = try? device.makeComputePipelineState(function: function)
    }

    func encodeCameraFrame(
        luminanceTexture: any MTLTexture,
        chromaTexture: any MTLTexture,
        targetTexture: any MTLTexture,
        viewToImageTransform: CGAffineTransform,
        time: CFTimeInterval,
        commandBuffer: any MTLCommandBuffer
    ) {
        guard
            let pipelineState,
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            return
        }

        var time = Float(time)
        var effectCount = essenceEffectCount
        var transform = SIMD4<Float>(
            Float(viewToImageTransform.a),
            Float(viewToImageTransform.b),
            Float(viewToImageTransform.c),
            Float(viewToImageTransform.d)
        )
        var translation = SIMD2<Float>(
            Float(viewToImageTransform.tx),
            Float(viewToImageTransform.ty)
        )
        var lensIntensity = lensIntensity

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(luminanceTexture, index: 0)
        encoder.setTexture(chromaTexture, index: 1)
        encoder.setTexture(targetTexture, index: 2)
        encoder.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        encoder.setBytes(&effectCount, length: MemoryLayout<UInt32>.size, index: 1)
        essenceEffects.withUnsafeBytes { effects in
            encoder.setBytes(effects.baseAddress!, length: effects.count, index: 2)
        }
        encoder.setBytes(&transform, length: MemoryLayout<SIMD4<Float>>.size, index: 3)
        encoder.setBytes(&translation, length: MemoryLayout<SIMD2<Float>>.size, index: 4)
        encoder.setBytes(&lensIntensity, length: MemoryLayout<Float>.size, index: 5)

        let width = pipelineState.threadExecutionWidth
        let height = max(1, pipelineState.maxTotalThreadsPerThreadgroup / width)
        let threadsPerGroup = MTLSize(width: width, height: height, depth: 1)
        let threads = MTLSize(
            width: targetTexture.width,
            height: targetTexture.height,
            depth: 1
        )
        encoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
}
