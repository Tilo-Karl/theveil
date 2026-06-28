import Metal
import RealityKit

final class VeilCameraPostProcessor {
    private var pipelineState: MTLComputePipelineState?
    private var essenceEffects = Array(repeating: SIMD4<Float>.zero, count: 5)
    private var essenceEffectCount: UInt32 = 0

    func updateEssenceEffects(_ effects: [SIMD4<Float>]) {
        essenceEffectCount = UInt32(min(effects.count, essenceEffects.count))

        for index in essenceEffects.indices {
            essenceEffects[index] = index < effects.count ? effects[index] : .zero
        }
    }

    func install(on arView: ARView) {
        var callbacks = arView.renderCallbacks
        callbacks.prepareWithDevice = { [weak self] device in
            self?.prepare(with: device)
        }
        callbacks.postProcess = { [weak self] context in
            self?.render(context)
        }
        arView.renderCallbacks = callbacks
    }

    private func prepare(with device: any MTLDevice) {
        guard
            let library = device.makeDefaultLibrary(),
            let function = library.makeFunction(name: "veilColorGrade")
        else {
            return
        }

        pipelineState = try? device.makeComputePipelineState(function: function)
    }

    private func render(_ context: ARView.PostProcessContext) {
        guard
            let pipelineState,
            let encoder = context.commandBuffer.makeComputeCommandEncoder()
        else {
            return
        }

        var time = Float(context.time)
        var effectCount = essenceEffectCount
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(context.sourceColorTexture, index: 0)
        encoder.setTexture(context.targetColorTexture, index: 1)
        encoder.setBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        encoder.setBytes(&effectCount, length: MemoryLayout<UInt32>.size, index: 1)
        essenceEffects.withUnsafeBytes { effects in
            encoder.setBytes(effects.baseAddress!, length: effects.count, index: 2)
        }

        let width = pipelineState.threadExecutionWidth
        let height = max(1, pipelineState.maxTotalThreadsPerThreadgroup / width)
        let threadsPerGroup = MTLSize(width: width, height: height, depth: 1)
        let threads = MTLSize(
            width: context.targetColorTexture.width,
            height: context.targetColorTexture.height,
            depth: 1
        )
        encoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }
}
