import SwiftUI

struct ContainmentCellHUDControl: View {
    let cellCharge: Int
    let cellCapacity: Int
    let capacitorCharge: Int
    let capacitorCapacity: Int
    let isUnlocked: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                if isUnlocked, cellCharge > 0 {
                    Text(actionLabel)
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(accentColor)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(Color.black.opacity(0.62))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(accentColor.opacity(isEnabled ? 0.72 : 0.28), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(
                color: accentColor.opacity(isOverloadReady ? 0.45 : 0),
                radius: 8
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(AppStrings.activateContainmentCellAccessibilityLabel)
        .accessibilityValue("\(cellCharge) of \(cellCapacity)")
    }

    private var isOverloadReady: Bool {
        isUnlocked
            && cellCharge > 0
            && capacitorCharge >= capacitorCapacity
    }

    private var refillAmount: Int {
        min(max(capacitorCapacity - capacitorCharge, 0), cellCharge)
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

    private var actionLabel: String {
        if isOverloadReady {
            return "\(AppStrings.overloadCapacitorLabel) +\(cellCharge)"
        }
        return "\(AppStrings.refillCapacitorLabel) +\(refillAmount)"
    }

    private var accentColor: Color {
        if isOverloadReady {
            return Color(red: 1, green: 0.45, blue: 0.24)
        }
        if isEnabled {
            return .cyan
        }
        return .white.opacity(0.38)
    }
}
