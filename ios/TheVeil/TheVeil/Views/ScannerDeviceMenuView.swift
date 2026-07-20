import SwiftUI

struct ScannerDeviceMenuView: View {
    @ObservedObject var inventoryStore: EssenceInventoryStore
    @ObservedObject var researchStore: WispResearchStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("STORAGE") {
                    storageRow(
                        title: "VEIL CAPACITOR",
                        value: AppStrings.capacitorCharge(
                            inventoryStore.capacitorEssenceCount,
                            capacity: inventoryStore.equipment.capacitorCapacity
                        ),
                        systemImage: "bolt.horizontal.circle"
                    )
                    storageRow(
                        title: AppStrings.integratedCellLabel,
                        value: integratedCellValue,
                        systemImage: "battery.100percent"
                    )
                }

                Section("RESEARCH") {
                    NavigationLink {
                        BookOfVeilogyView(
                            hasIdentifiedWisp: researchStore.hasIdentifiedWisp,
                            hasDocumentedEcto: researchStore.hasDocumentedEcto
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("BOOK OF VEILOGY")
                                    .font(.callout.monospaced().weight(.semibold))
                                Text(researchStatus)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(
                                        researchStore.hasIdentifiedWisp || researchStore.hasDocumentedEcto
                                            ? .cyan
                                            : .secondary
                                    )
                            }
                        } icon: {
                            Image(systemName: "book.closed")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.025, green: 0.035, blue: 0.055))
            .navigationTitle("SCANNER DEVICE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("DONE") {
                        dismiss()
                    }
                    .font(.caption.monospaced().weight(.semibold))
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var integratedCellValue: String {
        guard inventoryStore.isIntegratedCellUnlocked else {
            return AppStrings.lockedStorageValue
        }
        return "\(inventoryStore.containmentCellEssenceCount) / \(inventoryStore.equipment.containmentCellCapacity)"
    }

    private var researchStatus: String {
        if researchStore.hasIdentifiedWisp && researchStore.hasDocumentedEcto {
            return "FIELD ENTRIES UPDATED"
        }
        if researchStore.hasDocumentedEcto {
            return "ECTO ENTRY UPDATED"
        }
        if researchStore.hasIdentifiedWisp {
            return "WILL-O'-THE-WISP ENTRY UPDATED"
        }
        return AppStrings.wispResearchProgress(
            researchStore.uploadedSampleCount,
            required: WispResearchStore.identificationThreshold
        )
    }

    private func storageRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(title)
                .font(.callout.monospaced())
            Spacer()
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color(red: 0.7, green: 0.42, blue: 1))
        }
    }
}

private struct BookOfVeilogyView: View {
    let hasIdentifiedWisp: Bool
    let hasDocumentedEcto: Bool

    var body: some View {
        List {
            Section {
                Text("A living field guide of the Veil Society. Records expand as field researchers gather reliable evidence.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("FIELD DISCOVERIES") {
                NavigationLink {
                    VeilogyEntryView(entry: wispEntry)
                } label: {
                    VeilogyEntryRow(
                        title: hasIdentifiedWisp ? "WILL-O'-THE-WISP" : "UNIDENTIFIED ANOMALY",
                        classification: hasIdentifiedWisp ? "SPECTRAL ENERGY PHENOMENON" : "ANALYSIS INCOMPLETE",
                        isUpdated: hasIdentifiedWisp
                    )
                }

                NavigationLink {
                    VeilogyEntryView(entry: ectoEntry)
                } label: {
                    VeilogyEntryRow(
                        title: "ECTO",
                        classification: hasDocumentedEcto
                            ? "LESSER ESSENCE BEING"
                            : "ECTOPLASMIC ORGANISM - SAMPLE REQUIRED",
                        isUpdated: hasDocumentedEcto
                    )
                }
            }

            Section("FOUNDATIONS") {
                ForEach(VeilogyEntry.foundations) { entry in
                    NavigationLink {
                        VeilogyEntryView(entry: entry)
                    } label: {
                        VeilogyEntryRow(
                            title: entry.title,
                            classification: entry.classification,
                            isUpdated: false
                        )
                    }
                }
            }

            Section("GHOST CLASSIFICATIONS") {
                ForEach(VeilogyEntry.ghosts) { entry in
                    NavigationLink {
                        VeilogyEntryView(entry: entry)
                    } label: {
                        VeilogyEntryRow(
                            title: entry.title,
                            classification: entry.classification,
                            isUpdated: false
                        )
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.025, green: 0.035, blue: 0.055))
        .navigationTitle("BOOK OF VEILOLOGY")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var wispEntry: VeilogyEntry {
        if hasIdentifiedWisp {
            return VeilogyEntry(
                title: "WILL-O'-THE-WISP",
                classification: "SPECTRAL ENERGY PHENOMENON",
                body: "Despite centuries of folklore, a Will-o'-the-Wisp is not a ghost and possesses no soul. It is a naturally occurring concentration of free Veil Essence displaying limited autonomous behaviour. Modern Veil Scanners allow researchers to safely extract and contain its Veil Essence."
            )
        }

        return VeilogyEntry(
            title: "UNIDENTIFIED ANOMALY",
            classification: "ANALYSIS INCOMPLETE",
            body: "A mobile concentration of spectral energy has been observed. Additional synchronized samples are required before the phenomenon can be classified."
        )
    }

    private var ectoEntry: VeilogyEntry {
        guard hasDocumentedEcto else {
            return VeilogyEntry(
                title: "ECTO",
                classification: "ECTOPLASMIC ORGANISM - SAMPLE REQUIRED",
                threatLevel: "LOW",
                body: "A compact ectoplasmic organism has been observed in scanner tests. Its behaviour, structure and safe containment properties require an uploaded residual sample before the Book can publish a confirmed field entry.",
                sections: [
                    VeilogySection(
                        title: "RESEARCH REQUIREMENT",
                        body: "Acquire Resonance Lock, destabilize the entity with the Veil Scanner and upload the stabilized Ecto sample from the Veil Capacitor."
                    )
                ],
                researchStatus: [
                    VeilogyResearchItem(title: "Visual morphology observed", isDocumented: true),
                    VeilogyResearchItem(title: "Residual sample uploaded", isDocumented: false),
                    VeilogyResearchItem(title: "Ectoplasmic integrity measured", isDocumented: false)
                ]
            )
        }

        return VeilogyEntry.ecto
    }
}

private struct VeilogyEntryRow: View {
    let title: String
    let classification: String
    let isUpdated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.callout.monospaced().weight(.semibold))
                if isUpdated {
                    Text("UPDATED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
            }
            Text(classification)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

private struct VeilogyEntryView: View {
    let entry: VeilogyEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(entry.classification)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.cyan)

                if let threatLevel = entry.threatLevel {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.veilogyThreatLevelLabel)
                            .font(.caption2.monospaced().weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(threatLevel)
                            .font(.callout.monospaced().weight(.bold))
                            .foregroundStyle(Color(red: 0.72, green: 0.42, blue: 1))
                    }
                }

                Text(entry.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(5)

                ForEach(entry.sections) { section in
                    Divider().overlay(Color.cyan.opacity(0.2))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.cyan)
                        Text(section.body)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(5)
                    }
                }

                Divider().overlay(Color.cyan.opacity(0.2))
                VeilogyResearchStatusView(items: entry.researchStatus)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color(red: 0.025, green: 0.035, blue: 0.055))
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VeilogyResearchStatusView: View {
    let items: [VeilogyResearchItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.veilogyResearchStatusLabel)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(.cyan)

            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: item.isDocumented ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(item.isDocumented ? .cyan : .secondary)
                    Text(item.title)
                        .font(.callout)
                        .foregroundStyle(item.isDocumented ? .white.opacity(0.9) : .secondary)
                }
            }
        }
    }
}
