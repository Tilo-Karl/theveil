import AVFoundation
import Combine

@MainActor
final class ScannerAudioController: ObservableObject {
    private let engine = AVAudioEngine()
    private let humNode = AVAudioPlayerNode()
    private let scannerNoiseNode = AVAudioPlayerNode()
    private let effectNode = AVAudioPlayerNode()
    private let humBuffer: AVAudioPCMBuffer
    private let scannerNoiseBuffer: AVAudioPCMBuffer
    private let detectionBeepBuffer: AVAudioPCMBuffer
    private let containmentChirpBuffer: AVAudioPCMBuffer

    private var humScheduled = false
    private var scannerNoiseScheduled = false

    init() {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channels: 1
        )!
        humBuffer = Self.makeHumBuffer(format: format)
        scannerNoiseBuffer = Self.makeScannerNoiseBuffer(format: format)
        detectionBeepBuffer = Self.makeDetectionBeepBuffer(format: format)
        containmentChirpBuffer = Self.makeContainmentChirpBuffer(format: format)

        engine.attach(humNode)
        engine.attach(scannerNoiseNode)
        engine.attach(effectNode)
        engine.connect(humNode, to: engine.mainMixerNode, format: format)
        engine.connect(scannerNoiseNode, to: engine.mainMixerNode, format: format)
        engine.connect(effectNode, to: engine.mainMixerNode, format: format)

        humNode.volume = 0.52
        scannerNoiseNode.volume = 0.34
        effectNode.volume = 0.72
    }

    func startBootSequence() {
        configureAudioSession()

        if !engine.isRunning {
            try? engine.start()
        }

        if !humScheduled {
            humNode.scheduleBuffer(humBuffer, at: nil, options: .loops)
            humScheduled = true
        }
        if !humNode.isPlaying {
            humNode.play()
        }
    }

    func transition(to phase: ScannerStartupPhase) {
        guard phase != .booting else {
            return
        }

        if !scannerNoiseScheduled {
            scannerNoiseNode.scheduleBuffer(scannerNoiseBuffer, at: nil, options: .loops)
            scannerNoiseScheduled = true
        }
        if !scannerNoiseNode.isPlaying {
            scannerNoiseNode.play()
        }
    }

    func playDetectionBeep() {
        playEffect(detectionBeepBuffer)
    }

    func playContainmentChirp() {
        playEffect(containmentChirpBuffer)
    }

    func stop() {
        humNode.stop()
        scannerNoiseNode.stop()
        effectNode.stop()
        engine.stop()
        humScheduled = false
        scannerNoiseScheduled = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func playEffect(_ buffer: AVAudioPCMBuffer) {
        if !engine.isRunning {
            try? engine.start()
        }
        effectNode.stop()
        effectNode.scheduleBuffer(buffer)
        effectNode.play()
    }

    private static func makeHumBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * 2)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        for index in 0..<Int(frameCount) {
            let time = Float(index) / Float(format.sampleRate)
            let pulse = 0.86 + sin(2 * .pi * 0.7 * time) * 0.14
            samples[index] = (
                sin(2 * .pi * 55 * time) * 0.046
                    + sin(2 * .pi * 110 * time) * 0.014
                    + sin(2 * .pi * 220 * time) * 0.004
            ) * pulse
        }

        return buffer
    }

    private static func makeScannerNoiseBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * 2)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        var seed: UInt32 = 0xA341_316C
        var filteredNoise: Float = 0

        for index in 0..<Int(frameCount) {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            let whiteNoise = Float(seed & 0x00FF_FFFF) / Float(0x00FF_FFFF) * 2 - 1
            filteredNoise = filteredNoise * 0.82 + whiteNoise * 0.18

            let time = Float(index) / Float(format.sampleRate)
            let carrier = sin(2 * .pi * 1_760 * time) * 0.004
            let scannerPulse = max(0, sin(2 * .pi * 2.3 * time)) * 0.004
            samples[index] = filteredNoise * 0.032 + carrier + scannerPulse
        }

        return buffer
    }

    private static func makeDetectionBeepBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Float = 0.16
        let frameCount = AVAudioFrameCount(format.sampleRate * Double(duration))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        for index in 0..<Int(frameCount) {
            let progress = Float(index) / Float(max(Int(frameCount) - 1, 1))
            let envelope = sin(.pi * progress)
            let time = Float(index) / Float(format.sampleRate)
            samples[index] = sin(2 * .pi * 920 * time) * envelope * 0.18
        }

        return buffer
    }

    private static func makeContainmentChirpBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Float = 0.34
        let frameCount = AVAudioFrameCount(format.sampleRate * Double(duration))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let samples = buffer.floatChannelData![0]
        var phase: Float = 0
        for index in 0..<Int(frameCount) {
            let progress = Float(index) / Float(max(Int(frameCount) - 1, 1))
            let frequency = 560 + progress * 920
            phase += 2 * .pi * frequency / Float(format.sampleRate)
            let envelope = sin(.pi * progress)
            let overtone = sin(phase * 2.01) * 0.035
            samples[index] = (sin(phase) * 0.16 + overtone) * envelope
        }

        return buffer
    }
}
