import Foundation

struct VeilEquipmentConfiguration: Equatable, Sendable {
    let capacitorCapacity: Int
    let containmentCellCapacity: Int
    let resonancePulseDuration: TimeInterval
    let weakBeamOutput: Double
    let dischargeOutput: Double

    nonisolated static let fieldScanner = VeilEquipmentConfiguration(
        capacitorCapacity: 5,
        containmentCellCapacity: 5,
        resonancePulseDuration: 2,
        weakBeamOutput: 1,
        dischargeOutput: 1
    )
}

enum ContainmentTransferResult: Equatable {
    case noEssence
    case unidentifiedEssence
    case cellLocked
    case cellFull
    case transferred(essence: Int)
}

enum WispResearchUploadResult: Equatable {
    case noSamples
    case progress(current: Int, required: Int)
    case identified
    case contributed(samples: Int)
}
