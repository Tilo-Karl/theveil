import Foundation

enum ScannerStartupPhase: Equatable {
    case booting
    case engagingLens
    case active
}

enum ScannerSignalMode: Equatable {
    case passive
    case anomalyDetected
    case locking
}

enum ScannerGameplayPhase: Equatable {
    case calmSearch
    case charged
    case discharging
    case awakenedHunt
    case manifestation
}

enum ScannerNotice: Equatable {
    case essenceStored(capacitorCharge: Int, capacitorCapacity: Int)
    case capacitorCharged
    case capacitorEmpty
    case containmentCellEmpty
    case capacitorRefilled(
        transferred: Int,
        capacitorCharge: Int,
        capacitorCapacity: Int,
        cellCharge: Int,
        cellCapacity: Int
    )
    case capacitorOverloaded(peakCharge: Int, capacitorCapacity: Int)
    case essenceUploaded(samples: Int)
    case researchProgress(current: Int, required: Int)
    case essenceContained(transferred: Int, cellCharge: Int, cellCapacity: Int)
    case unidentifiedEssence
    case containmentCellLocked
    case containmentCellFull
    case containmentCellUnlocked
    case manifestationFieldCharged
    case awakenedHunt
    case manifestationDetected
    case entityCatalogued
    case libraryUpdated
}
