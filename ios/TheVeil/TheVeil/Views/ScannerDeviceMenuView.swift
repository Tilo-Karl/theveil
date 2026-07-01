import SwiftUI

struct ScannerDeviceMenuView: View {
    @ObservedObject var inventoryStore: EssenceInventoryStore
    let hasIdentifiedWisp: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("STORAGE") {
                    storageRow(
                        title: "VEIL CAPACITOR",
                        value: "\(inventoryStore.capacitorEssenceCount) / 5",
                        systemImage: "bolt.horizontal.circle"
                    )
                    storageRow(
                        title: "CONTAINMENT CELLS",
                        value: "\(inventoryStore.containmentCellCount)",
                        systemImage: "battery.100percent"
                    )
                }

                Section("RESEARCH") {
                    NavigationLink {
                        BookOfVeilogyView(hasIdentifiedWisp: hasIdentifiedWisp)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("BOOK OF VEILOGY")
                                    .font(.callout.monospaced().weight(.semibold))
                                Text(hasIdentifiedWisp ? "WILL-O'-THE-WISP ENTRY UPDATED" : "FIELD RECORDS")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(hasIdentifiedWisp ? .cyan : .secondary)
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
                Text(entry.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Color(red: 0.025, green: 0.035, blue: 0.055))
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VeilogyEntry: Identifiable {
    let id = UUID()
    let title: String
    let classification: String
    let body: String

    static let foundations = [
        VeilogyEntry(
            title: "THE VEIL SOCIETY",
            classification: "ORGANIZATION",
            body: "An ancient network of independent researchers devoted to observing, documenting and understanding supernatural phenomena. Its purpose is not to destroy the supernatural, but to understand it."
        ),
        VeilogyEntry(
            title: "VEILOLOGY",
            classification: "ACADEMIC DISCIPLINE",
            body: "The scientific study of the Veil. Veilogy classifies supernatural phenomena by observable origin, behaviour and measurable characteristics rather than myth or tradition."
        ),
        VeilogyEntry(
            title: "THE VEIL",
            classification: "INTERDIMENSIONAL BOUNDARY",
            body: "The invisible boundary separating the Natural World from the unknown Spirit World. It is not a place, but the membrane separating worlds."
        ),
        VeilogyEntry(
            title: "VEIL SCANNER",
            classification: "FIELD EQUIPMENT",
            body: "The primary investigative instrument of the Veil Society. It detects, analyses and temporarily stores Veil Essence, identifies known anomalies and documents field observations."
        ),
        VeilogyEntry(
            title: "VEIL ESSENCE",
            classification: "SPECTRAL ENERGY",
            body: "The fundamental energy associated with the Veil. It naturally permeates the boundary between worlds and possesses no known consciousness."
        ),
        VeilogyEntry(
            title: "ECTOPLASM",
            classification: "SPECTRAL MATTER",
            body: "Condensed spectral matter formed when Veil Essence interacts with the physical world. It may remain as recoverable residue after significant supernatural events."
        ),
        VeilogyEntry(
            title: "MANIFESTATION",
            classification: "VEIL EVENT",
            body: "An event in which disturbances in the Veil become severe enough to allow coherent supernatural phenomena to emerge into the Natural World."
        )
    ]

    static let ghosts = [
        VeilogyEntry(
            title: "GHOSTS",
            classification: "HUMAN SOUL",
            body: "The surviving soul of a once-living being that has not completed its passage through the Veil or has otherwise returned from it."
        ),
        VeilogyEntry(
            title: "LOST SOUL",
            classification: "GHOST - THREAT I",
            body: "A recently deceased soul that failed to complete its passage through the Veil. Most Lost Souls are confused rather than hostile."
        ),
        VeilogyEntry(
            title: "PHANTOM",
            classification: "GHOST - THREAT II",
            body: "A coherent ghost that recognizes itself, its surroundings and often its former life."
        ),
        VeilogyEntry(
            title: "REVENANT",
            classification: "GHOST - THREAT III",
            body: "A ghost that remains because of a singular unresolved purpose. Everything unrelated to that purpose gradually fades."
        ),
        VeilogyEntry(
            title: "WRAITH",
            classification: "GHOST - THREAT IV",
            body: "A ghost that has lost nearly all personal identity, leaving instinct and overwhelming emotion."
        ),
        VeilogyEntry(
            title: "POLTERGEIST",
            classification: "BEHAVIOURAL PHENOMENON",
            body: "Not a ghost species. Poltergeist is a designation for hauntings that exhibit sustained physical interaction with the material world."
        )
    ]
}
