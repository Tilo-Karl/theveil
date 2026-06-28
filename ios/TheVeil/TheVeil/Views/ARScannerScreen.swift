import SwiftUI

struct ARScannerScreen: View {
    @StateObject private var viewModel = ARScannerViewModel()

    var body: some View {
        ZStack {
            ARScannerView(viewModel: viewModel)
                .ignoresSafeArea()

            ScannerReticle(progress: viewModel.lockOnProgress)
                .allowsHitTesting(false)

            ScannerHUD(
                scannerStateStore: viewModel.scannerStateStore,
                inventoryStore: viewModel.inventoryStore,
                visibleEssenceStore: viewModel.visibleEssenceStore
            )
            .allowsHitTesting(false)
        }
    }
}

private struct ScannerReticle: View {
    let progress: Double

    var body: some View {
        ZStack {
            ReticleCorners()
                .stroke(
                    progress > 0 ? Color.cyan.opacity(0.95) : Color.white.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .square)
                )
                .frame(width: 84, height: 84)

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
                .fill(progress > 0 ? Color.cyan : Color.white.opacity(0.8))
                .frame(width: 4, height: 4)

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 20, height: 1)

            Rectangle()
                .fill(.white.opacity(0.7))
                .frame(width: 1, height: 20)
        }
        .shadow(color: .cyan.opacity(progress > 0 ? 0.8 : 0.2), radius: 8)
        .animation(.easeOut(duration: 0.12), value: progress)
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

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.scannerSignalLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.cyan.opacity(0.8))
                Text(AppStrings.scannerHintText(scannerStateStore.status))
                    .font(.caption)
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

    private var essenceTotal: Int {
        inventoryStore.ambientEssenceCount + visibleEssenceStore.visibleEssenceCount
    }

    private var collectionFraction: CGFloat {
        guard essenceTotal > 0 else { return 1 }
        return CGFloat(inventoryStore.ambientEssenceCount) / CGFloat(essenceTotal)
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
