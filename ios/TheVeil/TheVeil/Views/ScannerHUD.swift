import SwiftUI

struct ScannerHUD: View {
    @ObservedObject var viewModel: ARScannerViewModel
    @ObservedObject var scannerStateStore: ARScannerStateStore
    @ObservedObject var inventoryStore: EssenceInventoryStore
    @ObservedObject var encounterStore: ManifestationEncounterStore
    let capacitorAction: () -> Void
    let containmentCellAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack {
                Spacer()
                ContainmentCellHUDControl(
                    cellCharge: inventoryStore.containmentCellEssenceCount,
                    cellCapacity: inventoryStore.equipment.containmentCellCapacity,
                    capacitorCharge: inventoryStore.capacitorEssenceCount,
                    capacitorCapacity: inventoryStore.equipment.capacitorCapacity,
                    isUnlocked: inventoryStore.isIntegratedCellUnlocked,
                    isEnabled: viewModel.canActivateContainmentCell,
                    action: containmentCellAction
                )
            }
            .padding(.top, 6)
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

            Button(action: capacitorAction) {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(viewModel.counterLabel)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.65))

                    Text(
                        AppStrings.capacitorCharge(
                            inventoryStore.capacitorEssenceCount,
                            capacity: inventoryStore.equipment.capacitorCapacity
                        )
                    )
                        .font(.headline.monospacedDigit().weight(.medium))
                        .foregroundStyle(capacitorAccentColor)

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
            .buttonStyle(.plain)
            .disabled(!viewModel.canOperateCapacitor)
            .accessibilityLabel(AppStrings.openCapacitorActionsAccessibilityLabel)
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
                Text(viewModel.fieldCounterValue)
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
            return AppStrings.scannerNoticeStatus(notice)
        }

        if viewModel.resonanceBeamActive {
            return AppStrings.resonanceBeamProgress(viewModel.resonanceBeamProgress)
        }

        if scannerStateStore.status == .lostSoulManifested {
            return viewModel.signalMode == .locking
                ? AppStrings.entitySignalLockedStatus
                : AppStrings.entityResonanceDetectedStatus
        }

        switch viewModel.gameplayPhase {
        case .charged:
            return AppStrings.capacitorActionRequiredStatus
        case .discharging:
            return AppStrings.spectralPressureCriticalStatus
        case .awakenedHunt:
            if viewModel.signalMode == .locking {
                return AppStrings.resonanceLockProgress(viewModel.lockOnProgress)
            }
            return viewModel.signalMode == .anomalyDetected
                ? AppStrings.agitatedWispDetectedStatus
                : AppStrings.searchingAgitatedWispsStatus
        case .calmSearch, .manifestation:
            break
        }

        switch viewModel.signalMode {
        case .passive:
            return AppStrings.passiveSearchStatus
        case .anomalyDetected:
            return AppStrings.anomalyDetectedStatus
        case .locking:
            return AppStrings.resonanceLockProgress(viewModel.lockOnProgress)
        }
    }

    private var collectionFraction: CGFloat {
        let goal = viewModel.displayedCapacitorCapacity
        guard goal > 0 else { return 1 }
        return min(CGFloat(inventoryStore.capacitorEssenceCount) / CGFloat(goal), 1)
    }

    private var accentColor: Color {
        switch viewModel.gameplayPhase {
        case .discharging, .awakenedHunt, .manifestation:
            return Color(red: 0.7, green: 0.32, blue: 1)
        case .calmSearch, .charged:
            return Color(red: 0.66, green: 0.48, blue: 1)
        }
    }

    private var capacitorAccentColor: Color {
        inventoryStore.capacitorEssenceCount > inventoryStore.equipment.capacitorCapacity
            ? Color(red: 1, green: 0.45, blue: 0.24)
            : accentColor
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

                let isAgitated = gameplayPhase == .discharging
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

struct ScannerGlyph: View {
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
