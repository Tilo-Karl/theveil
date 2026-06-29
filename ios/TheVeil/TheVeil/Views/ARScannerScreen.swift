import SwiftUI

struct ARScannerScreen: View {
    @StateObject private var viewModel = ARScannerViewModel()
    @StateObject private var audioController = ScannerAudioController()

    var body: some View {
        ZStack {
            ARScannerView(viewModel: viewModel)
                .ignoresSafeArea()

            if viewModel.isScannerActive {
                ScannerReticle(
                    progress: viewModel.lockOnProgress,
                    signalMode: viewModel.signalMode
                )
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            ScannerHUD(
                viewModel: viewModel,
                scannerStateStore: viewModel.scannerStateStore,
                inventoryStore: viewModel.inventoryStore,
                visibleEssenceStore: viewModel.visibleEssenceStore
            )
            .opacity(viewModel.startupPhase == .booting ? 0 : Double(viewModel.lensIntensity))
            .allowsHitTesting(false)

            if let notice = viewModel.scannerNotice {
                ScannerNoticeOverlay(
                    notice: notice,
                    containedCount: viewModel.inventoryStore.ambientEssenceCount,
                    requiredCount: viewModel.inventoryStore.ambientEssenceCount
                        + viewModel.visibleEssenceStore.visibleEssenceCount
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 170)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if !viewModel.isScannerActive {
                ScannerBootOverlay(
                    phase: viewModel.startupPhase,
                    lensIntensity: viewModel.lensIntensity
                )
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            audioController.startBootSequence()
        }
        .onChange(of: viewModel.startupPhase) { _, phase in
            audioController.transition(to: phase)
        }
        .onChange(of: viewModel.detectionEventCounter) { _, eventCount in
            if eventCount > 0 {
                audioController.playDetectionBeep()
            }
        }
        .onChange(of: viewModel.containmentEventCounter) { _, eventCount in
            if eventCount > 0 {
                audioController.playContainmentChirp()
            }
        }
        .onDisappear {
            audioController.stop()
        }
    }
}

private struct ScannerBootOverlay: View {
    let phase: ScannerStartupPhase
    let lensIntensity: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let flicker = 0.94
                + sin(time * 41) * 0.025
                + sin(time * 89) * 0.012
            let engagementOpacity = 1 - Double(lensIntensity)

            ZStack {
                Color.black
                    .opacity(phase == .booting ? 0.78 : 0.5 * engagementOpacity)

                CRTScanlines(time: time)
                    .opacity(phase == .booting ? 0.72 : 0.72 * engagementOpacity)

                VStack(spacing: 16) {
                    ScannerGlyph()
                        .scaleEffect(1.55)

                    Text("VEIL SCANNER")
                        .font(.title2.monospaced().weight(.bold))
                        .foregroundStyle(.white)

                    Text(statusText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.cyan)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(.white.opacity(0.12))
                            Rectangle()
                                .fill(.cyan)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(width: 220, height: 2)
                }
                .opacity(phase == .booting ? flicker : engagementOpacity)
                .offset(x: phase == .booting ? sin(time * 67) * 0.65 : 0)
            }
        }
        .ignoresSafeArea()
    }

    private var statusText: String {
        switch phase {
        case .booting:
            "INITIALIZING SPECTRAL ARRAYS..."
        case .engagingLens:
            "SPECTRAL LENS ENGAGING..."
        case .active:
            "SPECTRAL ARRAY ONLINE"
        }
    }

    private var progress: CGFloat {
        switch phase {
        case .booting:
            0.32
        case .engagingLens:
            0.32 + CGFloat(lensIntensity) * 0.68
        case .active:
            1
        }
    }
}

private struct CRTScanlines: View {
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0.0, through: size.height, by: 4) {
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(.black.opacity(0.42))
                )
            }

            let sweep = time.truncatingRemainder(dividingBy: 2.8) / 2.8 * size.height
            context.fill(
                Path(CGRect(x: 0, y: sweep, width: size.width, height: 2)),
                with: .color(.cyan.opacity(0.18))
            )

            let tear = (sin(time * 17.0) * 0.5 + 0.5) * size.height
            context.fill(
                Path(CGRect(x: 0, y: tear, width: size.width, height: 1)),
                with: .color(.white.opacity(0.1))
            )
        }
    }
}

private struct ScannerReticle: View {
    let progress: Double
    let signalMode: ScannerSignalMode

    var body: some View {
        ZStack {
            ReticleCorners()
                .stroke(
                    hasAnomaly ? Color.cyan.opacity(0.95) : Color.white.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .square)
                )
                .frame(width: 84, height: 84)
                .scaleEffect(hasAnomaly ? 1 : 0.9)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.cyan, Color(red: 0.62, green: 0.35, blue: 1), .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0 ? 1 : 0)

            Circle()
                .fill(hasAnomaly ? Color.cyan : Color.white.opacity(0.8))
                .frame(width: 4, height: 4)

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 20, height: 1)

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 1, height: 20)
        }
        .shadow(color: .cyan.opacity(progress > 0 ? 0.8 : 0.2), radius: 8)
        .animation(.easeOut(duration: 0.16), value: signalMode)
        .animation(.easeOut(duration: 0.12), value: progress)
    }

    private var hasAnomaly: Bool {
        signalMode != .passive
    }
}

private struct ReticleCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = rect.width * 0.22
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return path
    }
}

private struct ScannerHUD: View {
    @ObservedObject var viewModel: ARScannerViewModel
    @ObservedObject var scannerStateStore: ARScannerStateStore
    @ObservedObject var inventoryStore: EssenceInventoryStore
    @ObservedObject var visibleEssenceStore: VisibleEssenceStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            footer
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ScannerGlyph()

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.scannerModeLabel)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(.cyan)
                        .frame(width: 20, height: 2)
                    Text(AppStrings.scannerStatusText(scannerStateStore.status).uppercased())
                        .font(.caption2.monospaced())
                        .foregroundStyle(.cyan.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(AppStrings.essenceCounterLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.65))

                Text("\(inventoryStore.ambientEssenceCount) / \(essenceTotal)")
                    .font(.headline.monospacedDigit().weight(.medium))
                    .foregroundStyle(Color(red: 0.66, green: 0.48, blue: 1))

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, Color(red: 0.58, green: 0.28, blue: 1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * collectionFraction)
                    }
                }
                .frame(width: 86, height: 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.52))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: scannerStateStore.status == .lostSoulManifested ? "scope" : "viewfinder")
                .font(.body.weight(.light))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.scannerSignalLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.cyan.opacity(0.8))

                SpectralResonanceMonitor(
                    strength: viewModel.signalStrength,
                    mode: viewModel.signalMode,
                    lockProgress: viewModel.lockOnProgress
                )
                .frame(height: 28)

                Text(signalStatusText)
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(AppStrings.visibleEssenceLabel.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(visibleEssenceStore.visibleEssenceCount)")
                    .font(.body.monospacedDigit().weight(.medium))
                    .foregroundStyle(Color(red: 0.66, green: 0.48, blue: 1))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.48))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0), .cyan.opacity(0.7), .purple.opacity(0.55), .cyan.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var signalStatusText: String {
        if let notice = viewModel.scannerNotice {
            switch notice {
            case .essenceContained:
                return "ESSENCE CONTAINED"
            case .synchronizing:
                return "SYNCHRONIZING SAMPLE SET"
            case .entityCatalogued:
                return "NEW ENTITY CATALOGUED"
            case .libraryUpdated:
                return "VEIL LIBRARY UPDATED"
            }
        }

        if scannerStateStore.status == .lostSoulManifested {
            return viewModel.signalMode == .locking
                ? "ENTITY SIGNAL LOCKED"
                : "ENTITY RESONANCE DETECTED"
        }

        switch viewModel.signalMode {
        case .passive:
            return "PASSIVE SEARCH"
        case .anomalyDetected:
            return "ANOMALY DETECTED"
        case .locking:
            return "CONTAINMENT LOCK  \(Int(viewModel.lockOnProgress * 100))%"
        }
    }

    private var essenceTotal: Int {
        inventoryStore.ambientEssenceCount + visibleEssenceStore.visibleEssenceCount
    }

    private var collectionFraction: CGFloat {
        guard essenceTotal > 0 else { return 1 }
        return CGFloat(inventoryStore.ambientEssenceCount) / CGFloat(essenceTotal)
    }
}

private struct SpectralResonanceMonitor: View {
    let strength: Double
    let mode: ScannerSignalMode
    let lockProgress: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let tick = Int(time * 18)
                let sampleCount = 56
                let regularity: Double

                switch mode {
                case .passive:
                    regularity = 0.05
                case .anomalyDetected:
                    regularity = 0.28
                case .locking:
                    regularity = 0.35 + min(lockProgress, 1) * 0.65
                }

                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: size.height / 2))
                        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    },
                    with: .color(.cyan.opacity(0.14)),
                    lineWidth: 1
                )

                var waveform = Path()
                for index in 0..<sampleCount {
                    let progress = Double(index) / Double(sampleCount - 1)
                    let x = size.width * progress
                    let noise = hashNoise(index: index, tick: tick)
                    let spike = noise > 0.88
                        ? (noise - 0.88) * 7.5
                        : 0
                    let staticSignal = (noise * 2 - 1) + spike
                    let stableSignal = sin(progress * 8 * .pi - time * 5.2)
                    let mixedSignal = staticSignal * (1 - regularity)
                        + stableSignal * regularity
                    let amplitude = 2.5 + min(max(strength, 0), 1) * 10.5
                    let y = size.height / 2 + mixedSignal * amplitude

                    if index == 0 {
                        waveform.move(to: CGPoint(x: x, y: y))
                    } else {
                        waveform.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    waveform,
                    with: .color(mode == .passive ? .cyan.opacity(0.62) : .cyan),
                    style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func hashNoise(index: Int, tick: Int) -> Double {
        let value = sin(Double(index * 127 + tick * 311) * 12.9898) * 43_758.5453
        return value - floor(value)
    }
}

private struct ScannerNoticeOverlay: View {
    let notice: ScannerNotice
    let containedCount: Int
    let requiredCount: Int

    var body: some View {
        VStack(spacing: 5) {
            switch notice {
            case .essenceContained:
                Text("ESSENCE CONTAINED")
                    .foregroundStyle(.cyan)
                Text("CONTAINMENT CELL  \(containedCount) / \(requiredCount)")
                    .foregroundStyle(.white.opacity(0.8))

            case .synchronizing:
                Text("ESSENCE REQUIRED")
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(containedCount) / \(requiredCount)")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color(red: 0.66, green: 0.48, blue: 1))
                Text("SYNCHRONIZING...")
                    .foregroundStyle(.cyan)

            case .entityCatalogued:
                Text("NEW ENTITY CATALOGUED")
                    .foregroundStyle(.cyan)

            case .libraryUpdated:
                Text("VEIL LIBRARY UPDATED")
                    .foregroundStyle(Color(red: 0.66, green: 0.48, blue: 1))
            }
        }
        .font(.caption.monospaced().weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.68))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.cyan.opacity(0.45), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.18), value: notice)
    }
}

private struct ScannerGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.cyan.opacity(0.45), lineWidth: 1)
            Circle()
                .stroke(.cyan.opacity(0.85), lineWidth: 1)
                .frame(width: 18, height: 18)
            Circle()
                .fill(.cyan)
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(.cyan.opacity(0.65))
                .frame(width: 36, height: 1)
            Rectangle()
                .fill(.cyan.opacity(0.65))
                .frame(width: 1, height: 36)
        }
        .frame(width: 36, height: 36)
        .shadow(color: .cyan.opacity(0.45), radius: 5)
    }
}

#Preview {
    ARScannerScreen()
}
