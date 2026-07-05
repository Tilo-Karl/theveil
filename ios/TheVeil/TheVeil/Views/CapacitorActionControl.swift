import SwiftUI

struct CapacitorActionControl: View {
    @ObservedObject var dischargeCircuitStore: DischargeCircuitStore
    @ObservedObject var encounterStore: ManifestationEncounterStore

    let capacitorCharge: Int
    let capacitorCapacity: Int
    let storageActionsEnabled: Bool
    let uploadAction: () -> Void
    let containAction: () -> Void
    let dischargeAction: () -> Void
    let closeAction: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            header
            manifestationStatus
            actions
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

    private var header: some View {
        HStack {
            Text(AppStrings.capacitorActionsTitle)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.cyan)
            Spacer()
            Text(
                AppStrings.capacitorCharge(
                    capacitorCharge,
                    capacity: capacitorCapacity
                )
            )
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.closeCapacitorActionsAccessibilityLabel)
        }
    }

    private var manifestationStatus: some View {
        VStack(spacing: 4) {
            HStack {
                Text(
                    AppStrings.manifestationFieldCharge(
                        AppStrings.resonanceValue(encounterStore.fieldCharge),
                        required: AppStrings.resonanceValue(encounterStore.requiredFieldCharge)
                    )
                )
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.cyan.opacity(0.85))

                Spacer()

                if dischargeCircuitStore.isActive {
                    Text("\(Int(dischargeCircuitStore.state.packetProgress * 100))%")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule()
                        .fill(.cyan)
                        .frame(
                            width: geometry.size.width * encounterStore.fieldChargeFraction
                        )
                }
            }
            .frame(height: 2)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            choiceButton(
                title: AppStrings.uploadActionTitle,
                subtitle: AppStrings.uploadActionSubtitle,
                systemImage: "arrow.up.circle",
                accent: .cyan,
                isEnabled: storageActionsEnabled,
                action: uploadAction
            )

            choiceButton(
                title: AppStrings.containActionTitle,
                subtitle: AppStrings.containActionSubtitle,
                systemImage: "battery.50percent",
                accent: .cyan,
                isEnabled: storageActionsEnabled,
                action: containAction
            )

            choiceButton(
                title: dischargeCircuitStore.isActive
                    ? AppStrings.stopDischargeActionTitle
                    : AppStrings.dischargeActionTitle,
                subtitle: dischargeCircuitStore.isActive
                    ? AppStrings.activeDischargeActionSubtitle
                    : AppStrings.dischargeActionSubtitle,
                systemImage: dischargeCircuitStore.isActive
                    ? "stop.fill"
                    : "bolt.trianglebadge.exclamationmark.fill",
                accent: Color(red: 0.72, green: 0.3, blue: 1),
                isEnabled: dischargeCircuitStore.isActive || capacitorCharge > 0,
                action: dischargeAction
            )
        }
    }

    private func choiceButton(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        isEnabled: Bool,
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(title)
    }

}
