import SwiftUI

struct ARScannerScreen: View {
    @StateObject private var viewModel = ARScannerViewModel()
    @StateObject private var audioController = ScannerAudioController()
    @State private var isDeviceMenuPresented = false

    var body: some View {
        ZStack {
            ARScannerView(viewModel: viewModel)
                .ignoresSafeArea()

            if viewModel.isScannerActive {
                ScannerReticle(
                    progress: viewModel.lockOnProgress,
                    signalMode: viewModel.signalMode,
                    gameplayPhase: viewModel.gameplayPhase
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
                    containedCount: viewModel.noticeContainedCount,
                    requiredCount: viewModel.noticeRequiredCount
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 170)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if viewModel.gameplayPhase == .charged {
                VStack {
                    Spacer()
                    CapacitorChoiceControl(
                        overloadAction: viewModel.activateOverload,
                        craftAction: viewModel.craftContainmentCell
                    )
                    .padding(.bottom, 126)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            if viewModel.isScannerActive {
                Button {
                    isDeviceMenuPresented = true
                } label: {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.body.monospaced().weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.68))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.cyan.opacity(0.42), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 116)
                .padding(.trailing, 20)
                .accessibilityLabel("Open scanner device menu")
            }

            #if DEBUG
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    DebugScannerControls(
                        autoLock: Binding(
                            get: { viewModel.debugAutoLockEnabled },
                            set: { viewModel.setDebugAutoLockEnabled($0) }
                        ),
                        phaseCube: Binding(
                            get: { viewModel.debugPhaseCubeEnabled },
                            set: { viewModel.setDebugPhaseCubeEnabled($0) }
                        ),
                        traversalStatus: viewModel.debugTraversalStatus
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 190)
            }
            #endif

            if
                viewModel.gameplayPhase == .overloading,
                let overloadStartedAt = viewModel.overloadStartedAt
            {
                ScannerOverloadTransition(startedAt: overloadStartedAt)
                    .allowsHitTesting(false)
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
        .onChange(of: viewModel.overloadEventCounter) { _, eventCount in
            if eventCount > 0 {
                audioController.playOverloadPulse()
            }
        }
        .onDisappear {
            audioController.stop()
        }
        .sheet(isPresented: $isDeviceMenuPresented) {
            ScannerDeviceMenuView(
                inventoryStore: viewModel.inventoryStore,
                hasIdentifiedWisp: viewModel.hasIdentifiedWisp
            )
        }
    }
}

#if DEBUG
private struct DebugScannerControls: View {
    @Binding var autoLock: Bool
    @Binding var phaseCube: Bool
    let traversalStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle(isOn: $autoLock) {
                Label("AUTO LOCK", systemImage: "scope")
            }
            Toggle(isOn: $phaseCube) {
                Label("PHASE CUBE", systemImage: "cube.transparent")
            }

            Text(traversalStatus)
                .foregroundStyle(.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.caption2.monospaced().weight(.semibold))
        .toggleStyle(.switch)
        .tint(Color(red: 0.7, green: 0.32, blue: 1))
        .foregroundStyle(.white)
        .padding(10)
        .frame(width: 190)
        .background(Color.black.opacity(0.72))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
#endif

private struct CapacitorChoiceControl: View {
    let overloadAction: () -> Void
    let craftAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("VEIL CAPACITOR FULL")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.cyan)

            HStack(spacing: 8) {
                choiceButton(
                    title: "OVERLOAD",
                    subtitle: "DISTURB THE VEIL",
                    systemImage: "bolt.trianglebadge.exclamationmark.fill",
                    accent: Color(red: 0.72, green: 0.3, blue: 1),
                    action: overloadAction
                )

                choiceButton(
                    title: "CRAFT CELL",
                    subtitle: "PERMANENT STORAGE",
                    systemImage: "battery.100percent",
                    accent: .cyan,
                    action: craftAction
                )
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.78))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.cyan.opacity(0.38), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 20)
    }

    private func choiceButton(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.caption.monospaced().weight(.bold))
                Text(subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(accent.opacity(0.14))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(accent.opacity(0.9), lineWidth: 1.25)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ScannerOverloadTransition: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startedAt)
            let flash = max(0, 1 - abs(elapsed - 0.48) / 0.16)
            let scatter = min(max((elapsed - 0.5) / 0.68, 0), 1)

            ZStack {
                Color.white
                    .opacity(flash * 0.42)

                Circle()
                    .stroke(Color.white.opacity((1 - scatter) * 0.75), lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(0.25 + scatter * 5.4)

                Circle()
                    .stroke(
                        Color(red: 0.64, green: 0.22, blue: 1)
                            .opacity((1 - scatter) * 0.8),
                        lineWidth: 2
                    )
                    .frame(width: 90, height: 90)
                    .scaleEffect(0.2 + scatter * 4.1)
            }
        }
        .ignoresSafeArea()
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
    let gameplayPhase: ScannerGameplayPhase

    var body: some View {
        ZStack {
            ReticleCorners()
                .stroke(
                    hasAnomaly ? activeColor.opacity(0.95) : Color.white.opacity(0.65),
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
                .fill(hasAnomaly ? activeColor : Color.white.opacity(0.8))
                .frame(width: 4, height: 4)

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 20, height: 1)

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 1, height: 20)
        }
        .shadow(color: activeColor.opacity(progress > 0 ? 0.8 : 0.2), radius: 8)
        .animation(.easeOut(duration: 0.16), value: signalMode)
        .animation(.easeOut(duration: 0.12), value: progress)
    }

    private var hasAnomaly: Bool {
        signalMode != .passive
    }

    private var activeColor: Color {
        gameplayPhase == .awakenedHunt
            ? Color(red: 0.74, green: 0.32, blue: 1)
            : .cyan
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
                Text(viewModel.counterLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.65))

                Text("\(viewModel.displayedContainedCount) / \(viewModel.displayedContainmentGoal)")
                    .font(.headline.monospacedDigit().weight(.medium))
                    .foregroundStyle(accentColor)

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
                .stroke(accentColor.opacity(0.28), lineWidth: 1)
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
                    lockProgress: viewModel.lockOnProgress,
                    gameplayPhase: viewModel.gameplayPhase
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
                Text(viewModel.fieldCounterLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(visibleEssenceStore.visibleEssenceCount)")
                    .font(.body.monospacedDigit().weight(.medium))
                    .foregroundStyle(accentColor)
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
                return "ESSENCE STORED"
            case .capacitorCharged:
                return "VEIL CAPACITOR CHARGED"
            case .containmentCellCrafted:
                return "CONTAINMENT CELL CRAFTED"
            case .overloading:
                return "DISCHARGING VEIL CAPACITOR"
            case .awakenedHunt:
                return "AGITATED SIGNALS RELEASED"
            case .synchronizing:
                return "SYNCHRONIZING SAMPLE SET"
            case .entityCatalogued:
                return "WILL-O'-THE-WISP IDENTIFIED"
            case .libraryUpdated:
                return "VEILOLOGY UPDATED"
            }
        }

        if scannerStateStore.status == .lostSoulManifested {
            return viewModel.signalMode == .locking
                ? "ENTITY SIGNAL LOCKED"
                : "ENTITY RESONANCE DETECTED"
        }

        switch viewModel.gameplayPhase {
        case .charged:
            return "CAPACITOR CHOICE REQUIRED"
        case .overloading:
            return "SPECTRAL PRESSURE CRITICAL"
        case .awakenedHunt:
            if viewModel.signalMode == .locking {
                return "AGITATED LOCK  \(Int(viewModel.lockOnProgress * 100))%"
            }
            return viewModel.signalMode == .anomalyDetected
                ? "AGITATED WISP DETECTED"
                : "SEARCHING FOR AGITATED WISPS"
        case .calmSearch, .manifestation:
            break
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

    private var collectionFraction: CGFloat {
        let goal = viewModel.displayedContainmentGoal
        guard goal > 0 else { return 1 }
        return min(CGFloat(viewModel.displayedContainedCount) / CGFloat(goal), 1)
    }

    private var accentColor: Color {
        switch viewModel.gameplayPhase {
        case .overloading, .awakenedHunt, .manifestation:
            return Color(red: 0.7, green: 0.32, blue: 1)
        case .calmSearch, .charged:
            return Color(red: 0.66, green: 0.48, blue: 1)
        }
    }
}

private struct SpectralResonanceMonitor: View {
    let strength: Double
    let mode: ScannerSignalMode
    let lockProgress: Double
    let gameplayPhase: ScannerGameplayPhase

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

                let isAgitated = gameplayPhase == .overloading
                    || gameplayPhase == .awakenedHunt
                    || gameplayPhase == .manifestation

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
                    let frequency = isAgitated ? 13.0 : 8.0
                    let speed = isAgitated ? 8.4 : 5.2
                    let stableSignal = sin(progress * frequency * .pi - time * speed)
                    let mixedSignal = staticSignal * (1 - regularity)
                        + stableSignal * regularity
                    let agitationBoost = isAgitated ? 2.5 : 0
                    let amplitude = 2.5 + min(max(strength, 0), 1) * 10.5 + agitationBoost
                    let y = size.height / 2 + mixedSignal * amplitude

                    if index == 0 {
                        waveform.move(to: CGPoint(x: x, y: y))
                    } else {
                        waveform.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    waveform,
                    with: .color(
                        isAgitated
                            ? Color(red: 0.72, green: 0.3, blue: 1)
                            : (mode == .passive ? .cyan.opacity(0.62) : .cyan)
                    ),
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
                Text("ESSENCE STORED")
                    .foregroundStyle(.cyan)
                Text("VEIL CAPACITOR  \(containedCount) / \(requiredCount)")
                    .foregroundStyle(.white.opacity(0.8))

            case .capacitorCharged:
                Text("VEIL CAPACITOR CHARGED")
                    .foregroundStyle(Color(red: 0.7, green: 0.34, blue: 1))
                Text("OVERLOAD OR CRAFT")
                    .foregroundStyle(.white.opacity(0.78))

            case .containmentCellCrafted:
                Text("CONTAINMENT CELL CRAFTED")
                    .foregroundStyle(.cyan)
                Text("PERMANENT STORAGE +1")
                    .foregroundStyle(.white.opacity(0.78))

            case .overloading:
                Text("SPECTRAL OVERLOAD")
                    .foregroundStyle(.white)
                Text("DISCHARGING VEIL CAPACITOR")
                    .foregroundStyle(Color(red: 0.72, green: 0.34, blue: 1))

            case .awakenedHunt:
                Text("WISPS AGITATED")
                    .foregroundStyle(Color(red: 0.72, green: 0.34, blue: 1))
                Text("CONTAIN 3 UNSTABLE SIGNALS")
                    .foregroundStyle(.white.opacity(0.82))

            case .synchronizing:
                Text(requiredCount == 3 ? "AGITATED ESSENCE" : "ESSENCE REQUIRED")
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(containedCount) / \(requiredCount)")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color(red: 0.66, green: 0.48, blue: 1))
                Text("SYNCHRONIZING...")
                    .foregroundStyle(.cyan)

            case .entityCatalogued:
                Text("WILL-O'-THE-WISP IDENTIFIED")
                    .foregroundStyle(.cyan)

            case .libraryUpdated:
                Text("VEILOLOGY UPDATED")
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
