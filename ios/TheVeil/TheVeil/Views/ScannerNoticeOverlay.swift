import SwiftUI

struct ScannerNoticeOverlay: View {
    let notice: ScannerNotice

    var body: some View {
        VStack(spacing: 5) {
            Text(AppStrings.scannerNoticeTitle(notice))
                .foregroundStyle(noticeAccent)

            if let detail = AppStrings.scannerNoticeDetail(notice) {
                Text(detail)
                    .foregroundStyle(.white.opacity(0.8))
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

    private var noticeAccent: Color {
        switch notice {
        case .manifestationFieldCharged, .awakenedHunt, .manifestationDetected,
             .capacitorOverloaded:
            return Color(red: 0.72, green: 0.34, blue: 1)
        case .capacitorEmpty, .containmentCellEmpty, .unidentifiedEssence,
             .containmentCellLocked, .containmentCellFull:
            return Color(red: 1, green: 0.55, blue: 0.24)
        case .essenceStored, .capacitorCharged, .capacitorRefilled, .essenceUploaded,
             .researchProgress, .essenceContained, .containmentCellUnlocked,
             .entityCatalogued, .libraryUpdated:
            return .cyan
        }
    }
}
