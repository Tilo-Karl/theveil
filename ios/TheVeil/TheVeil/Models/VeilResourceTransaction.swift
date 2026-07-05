import Foundation

struct VeilEquipmentConfiguration: Equatable, Sendable {
    let capacitorCapacity: Int
    let containmentCellCapacity: Int

    nonisolated static let fieldScanner = VeilEquipmentConfiguration(
        capacitorCapacity: 5,
        containmentCellCapacity: 5
    )
}

enum ContainmentTransferResult: Equatable {
    case noEssence
    case unidentifiedEssence
    case cellLocked
    case cellFull
    case transferred(essence: Int)
}

enum ContainmentCellActivationResult: Equatable {
    case cellLocked
    case cellEmpty
    case capacitorRefilled(
        transferredEssence: Int,
        capacitorCharge: Int,
        cellCharge: Int
    )
    case capacitorOverloaded(
        peakCharge: Int,
        capacitorCapacity: Int,
        injectedEssence: Int
    )
}

enum WispResearchUploadResult: Equatable {
    case noSamples
    case progress(current: Int, required: Int)
    case identified
    case contributed(samples: Int)
}
