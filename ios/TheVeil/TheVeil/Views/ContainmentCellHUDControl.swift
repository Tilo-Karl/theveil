import SwiftUI

struct ContainmentCellHUDControl: View {
    let cellCharge: Int
    let cellCapacity: Int
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isUnlocked ? "battery.100percent" : "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(AppStrings.containmentCellHUDLabel)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(cellValue)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(accentColor)
            }

        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(Color.black.opacity(0.62))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(accentColor.opacity(isUnlocked ? 0.72 : 0.28), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel(AppStrings.containmentCellHUDLabel)
        .accessibilityValue("\(cellCharge) of \(cellCapacity)")
    }

    private var cellValue: String {
        guard isUnlocked else {
            return AppStrings.lockedStorageValue
        }
        guard cellCharge > 0 else {
            return AppStrings.containmentCellEmptyValue
        }
        return "\(cellCharge) / \(cellCapacity)"
    }

    private var accentColor: Color {
        if isUnlocked && cellCharge > 0 {
            return .cyan
        }
        return .white.opacity(0.38)
    }
}
