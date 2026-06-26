import SwiftUI

struct ARScannerScreen: View {
    @StateObject private var viewModel = ARScannerViewModel()

    var body: some View {
        ZStack {
            ARScannerView(viewModel: viewModel)
                .ignoresSafeArea()

            ScannerHUD(
                scannerStateStore: viewModel.scannerStateStore,
                inventoryStore: viewModel.inventoryStore,
                visibleEssenceStore: viewModel.visibleEssenceStore
            )
        }
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
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppStrings.scannerTitle)
                    .font(.title2.weight(.semibold))
                Text(AppStrings.scannerStatusText(scannerStateStore.status))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppStrings.ambientEssenceLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(inventoryStore.ambientEssenceCount)")
                    .font(.title2.monospacedDigit().weight(.semibold))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Label(AppStrings.collectingHint, systemImage: "hand.tap")
            Spacer(minLength: 12)
            Text("\(AppStrings.visibleEssenceLabel): \(visibleEssenceStore.visibleEssenceCount)")
                .monospacedDigit()
        }
        .font(.footnote.weight(.medium))
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    ARScannerScreen()
}
