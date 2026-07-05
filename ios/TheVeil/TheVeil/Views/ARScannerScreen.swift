import SwiftUI

struct ARScannerScreen: View {
    @StateObject private var viewModel = ARScannerViewModel()
    @StateObject private var audioController = ScannerAudioController()
    @State private var isDeviceMenuPresented = false
    @State private var isCapacitorActionsPresented = false

    var body: some View {
        ZStack {
            ARScannerView(viewModel: viewModel)
                .ignoresSafeArea()

            if viewModel.isScannerActive {
                ScannerReticle(
                    progress: viewModel.lockOnProgress,
                    beamProgress: viewModel.resonanceBeamProgress,
                    beamActive: viewModel.resonanceBeamActive,
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
                encounterStore: viewModel.encounterStore,
                capacitorAction: {
                    guard viewModel.canOperateCapacitor else { return }
                    isCapacitorActionsPresented.toggle()
                },
                containmentCellAction: {
                    isCapacitorActionsPresented = false
                    viewModel.activateContainmentCell()
                }
            )
            .opacity(viewModel.startupPhase == .booting ? 0 : Double(viewModel.lensIntensity))

            if let notice = viewModel.scannerNotice {
                ScannerNoticeOverlay(notice: notice)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 170)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if isCapacitorActionsPresented, viewModel.canOperateCapacitor {
                VStack {
                    Spacer()
                    CapacitorActionControl(
                        dischargeCircuitStore: viewModel.dischargeCircuitStore,
                        encounterStore: viewModel.encounterStore,
                        capacitorCharge: viewModel.inventoryStore.capacitorEssenceCount,
                        capacitorCapacity: viewModel.inventoryStore.equipment.capacitorCapacity,
                        storageActionsEnabled: viewModel.canManageCapacitorStorage,
                        uploadAction: {
                            isCapacitorActionsPresented = false
                            viewModel.uploadCapacitorEssence()
                        },
                        containAction: {
                            isCapacitorActionsPresented = false
                            viewModel.containCapacitorEssence()
                        },
                        dischargeAction: {
                            let wasDischarging = viewModel.dischargeCircuitStore.isActive
                            viewModel.dischargeCapacitorEssence()
                            if wasDischarging {
                                isCapacitorActionsPresented = false
                            }
                        },
                        closeAction: {
                            isCapacitorActionsPresented = false
                        }
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
                .padding(.top, 174)
                .padding(.trailing, 20)
                .accessibilityLabel("Open scanner device menu")
            }

            if
                viewModel.gameplayPhase == .discharging,
                let dischargeStartedAt = viewModel.manifestationPulseStartedAt
            {
                ScannerDischargeTransition(startedAt: dischargeStartedAt)
                    .allowsHitTesting(false)
            }

            if let megaBeamStartedAt = viewModel.megaBeamStartedAt {
                MegaResonanceBeamOverlay(
                    startedAt: megaBeamStartedAt,
                    currentCharge: viewModel.inventoryStore.capacitorEssenceCount,
                    peakCharge: viewModel.megaBeamPeakCharge,
                    capacitorCapacity: viewModel.inventoryStore.equipment.capacitorCapacity,
                    intensity: viewModel.megaBeamIntensity
                )
                .allowsHitTesting(false)
            }

            if viewModel.resonanceBeamActive, viewModel.megaBeamStartedAt == nil {
                ResonanceBeamOverlay(progress: viewModel.resonanceBeamProgress)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if !viewModel.isScannerActive {
                ScannerBootOverlay(
                    phase: viewModel.startupPhase,
                    lensIntensity: viewModel.lensIntensity
                )
                .allowsHitTesting(false)
            }

            #if DEBUG
            if !isCapacitorActionsPresented {
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
            }
            #endif
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
        .onChange(of: viewModel.resonanceBeamActive) { _, active in
            audioController.setResonanceBeamActive(active)
        }
        .onChange(of: viewModel.essenceStorageEventCounter) { _, eventCount in
            if eventCount > 0 {
                audioController.playEssenceStorageChirp()
            }
        }
        .onChange(of: viewModel.manifestationPulseEventCounter) { _, eventCount in
            if eventCount > 0 {
                audioController.playDischargePulse()
            }
        }
        .onChange(of: viewModel.megaBeamEventCounter) { _, eventCount in
            if eventCount > 0 {
                audioController.playMegaResonanceBeam(intensity: viewModel.megaBeamIntensity)
            }
        }
        .onDisappear {
            audioController.stop()
        }
        .sheet(isPresented: $isDeviceMenuPresented) {
            ScannerDeviceMenuView(
                inventoryStore: viewModel.inventoryStore,
                researchStore: viewModel.researchStore
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

private struct ScannerDischargeTransition: View {
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
    let beamProgress: Double
    let beamActive: Bool
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
                .trim(from: 0, to: beamProgress)
                .stroke(
                    Color.white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .opacity(beamActive || beamProgress > 0 ? 1 : 0)

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
        .animation(.easeOut(duration: 0.12), value: beamProgress)
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

#Preview {
    ARScannerScreen()
}
