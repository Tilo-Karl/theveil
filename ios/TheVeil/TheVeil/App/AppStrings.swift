import Foundation

enum AppStrings {
    static let scannerTitle = "The Veil"
    static let scannerModeLabel = "VEIL SCANNER"
    static let scannerSignalLabel = "SPECTRAL RESONANCE"
    static let essenceCounterLabel = "VEIL CAPACITOR"
    static let fieldCounterLabel = "FIELD"
    static let manifestationCounterLabel = "MANIFEST"
    static let resupplyCounterLabel = "RESUPPLY"
    static let dormantCounterLabel = "DORMANT"
    static let releasingCounterLabel = "RELEASING"
    static let agitatedCounterLabel = "AGITATED"
    static let resonanceCounterLabel = "RESONANCE"
    static let capacitorActionsTitle = "VEIL CAPACITOR"
    static let uploadActionTitle = "UPLOAD"
    static let uploadActionSubtitle = "RESEARCH"
    static let containActionTitle = "CONTAIN"
    static let containActionSubtitle = "TRANSFER TO CELL"
    static let dischargeActionTitle = "DISCHARGE"
    static let dischargeActionSubtitle = "RELEASE CHARGE"
    static let stopDischargeActionTitle = "STOP"
    static let activeDischargeActionSubtitle = "CIRCUIT ACTIVE"
    static let closeCapacitorActionsAccessibilityLabel = "Close Capacitor actions"
    static let openCapacitorActionsAccessibilityLabel = "Open Capacitor actions"
    static let integratedCellLabel = "INTEGRATED CONTAINMENT CELL"
    static let containmentCellHUDLabel = "CELL"
    static let containmentCellEmptyValue = "EMPTY"
    static let refillCapacitorLabel = "REFILL"
    static let overloadCapacitorLabel = "OVERLOAD"
    static let activateContainmentCellAccessibilityLabel = "Activate Containment Cell"
    static let lockedStorageValue = "LOCKED"
    static let entitySignalLockedStatus = "ENTITY SIGNAL LOCKED"
    static let resonanceBeamEngagedStatus = "RESONANCE BEAM ENGAGED"
    static let entityResonanceDetectedStatus = "ENTITY RESONANCE DETECTED"
    static let capacitorActionRequiredStatus = "CAPACITOR CHOICE REQUIRED"
    static let spectralPressureCriticalStatus = "SPECTRAL PRESSURE CRITICAL"
    static let agitatedWispDetectedStatus = "AGITATED WISP DETECTED"
    static let searchingAgitatedWispsStatus = "SEARCHING FOR AGITATED WISPS"
    static let passiveSearchStatus = "PASSIVE SEARCH"
    static let anomalyDetectedStatus = "ANOMALY DETECTED"
    static let veilogyThreatLevelLabel = "THREAT LEVEL"
    static let veilogyResearchStatusLabel = "RESEARCH STATUS"

    static func wispResearchProgress(_ current: Int, required: Int) -> String {
        "WISP RESEARCH \(current) / \(required)"
    }

    static func manifestationFieldCharge(_ current: String, required: String) -> String {
        "MANIFESTATION  \(current) / \(required)"
    }

    static func resonanceValue(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.01 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", value)
    }
    static let ambientEssenceLabel = "Collected"
    static let visibleEssenceLabel = "Remaining"
    static let scannerUnavailableTitle = "AR scanner unavailable"
    static let scannerUnavailableMessage = "Open The Veil on an ARKit-capable device to scan for ambient essence."
    static let collectingHint = "Move close and aim at essence to collect it."
    static let minorSpecterHint = "Hold the reticle on the Minor Specter."
    static let cameraUsageDescription = "The Veil uses the camera to scan your surroundings for ambient Veil Essence."

    static func scannerStatusText(_ status: ARScannerStatus) -> String {
        switch status {
        case .initializing:
            return "Opening scanner"
        case .scanning:
            return "Scanning for ambient essence"
        case .charged:
            return "Veil Capacitor charged"
        case .discharging:
            return "Discharging Veil Capacitor"
        case .hunting:
            return "Tracking agitated essence"
        case .minorSpecterManifested:
            return "Minor Specter manifested"
        case .unavailable:
            return scannerUnavailableTitle
        }
    }

    static func scannerHintText(_ status: ARScannerStatus) -> String {
        switch status {
        case .minorSpecterManifested:
            return minorSpecterHint
        case .initializing, .scanning, .charged, .discharging, .hunting, .unavailable:
            return collectingHint
        }
    }

    static func capacitorCharge(_ charge: Int, capacity: Int) -> String {
        "\(charge) / \(capacity)"
    }

    static func resonanceLockProgress(_ progress: Double) -> String {
        "RESONANCE LOCK  \(Int(progress * 100))%"
    }

    static func resonanceBeamProgress(_ progress: Double) -> String {
        guard progress < 1 else {
            return resonanceBeamEngagedStatus
        }
        return "RESONANCE BEAM  \(Int(progress * 100))%"
    }

    static func scannerNoticeStatus(_ notice: ScannerNotice) -> String {
        switch notice {
        case .essenceStored:
            return "ESSENCE STORED"
        case .capacitorCharged:
            return "VEIL CAPACITOR CHARGED"
        case .capacitorEmpty:
            return "VEIL CAPACITOR EMPTY"
        case .containmentCellEmpty:
            return "CONTAINMENT CELL EMPTY"
        case .capacitorRefilled:
            return "CAPACITOR RELOADED"
        case .capacitorOverloaded:
            return "CAPACITOR OVERLOAD"
        case .essenceUploaded:
            return "RESEARCH UPLOAD COMPLETE"
        case .researchProgress:
            return "WISP ANALYSIS UPDATED"
        case .essenceContained:
            return "ESSENCE CONTAINED"
        case .unidentifiedEssence:
            return "UNKNOWN ESSENCE"
        case .containmentCellLocked:
            return "CONTAINMENT CELL OFFLINE"
        case .containmentCellFull:
            return "CONTAINMENT CELL FULL"
        case .containmentCellUnlocked:
            return "CONTAINMENT CELL ONLINE"
        case .manifestationFieldCharged:
            return "MANIFESTATION FIELD CHARGED"
        case .awakenedHunt:
            return "AGITATED SIGNALS RELEASED"
        case .manifestationDetected:
            return "UNKNOWN ENTITY DETECTED"
        case .entityCatalogued:
            return "WILL-O'-THE-WISP IDENTIFIED"
        case .libraryUpdated:
            return "VEILOLOGY UPDATED"
        }
    }

    static func scannerNoticeTitle(_ notice: ScannerNotice) -> String {
        scannerNoticeStatus(notice)
    }

    static func scannerNoticeDetail(_ notice: ScannerNotice) -> String? {
        switch notice {
        case .essenceStored(let capacitorCharge, let capacitorCapacity):
            return "VEIL CAPACITOR  \(capacitorCharge) / \(capacitorCapacity)"
        case .capacitorCharged:
            return "TAP CAPACITOR TO OPERATE"
        case .capacitorEmpty:
            return "NO ESSENCE AVAILABLE"
        case .containmentCellEmpty:
            return "NO STORED ESSENCE AVAILABLE"
        case .capacitorRefilled(
            let transferred,
            let capacitorCharge,
            let capacitorCapacity,
            let cellCharge,
            let cellCapacity
        ):
            return "+\(transferred)  CAP \(capacitorCharge) / \(capacitorCapacity)  CELL \(cellCharge) / \(cellCapacity)"
        case .capacitorOverloaded(let peakCharge, let capacitorCapacity):
            return "MEGA RESONANCE BEAM  \(peakCharge) / \(capacitorCapacity)"
        case .essenceUploaded(let samples):
            return "\(samples) SAMPLE\(samples == 1 ? "" : "S") ANALYZED"
        case .researchProgress(let current, let required):
            return "WISP RESEARCH  \(current) / \(required)"
        case .essenceContained(let transferred, let cellCharge, let cellCapacity):
            return "+\(transferred)  CELL \(cellCharge) / \(cellCapacity)"
        case .unidentifiedEssence:
            return "UPLOAD SAMPLES BEFORE CONTAINMENT"
        case .containmentCellLocked:
            return "COMPLETE WISP RESEARCH"
        case .containmentCellFull:
            return "NO ESSENCE TRANSFERRED"
        case .containmentCellUnlocked:
            return "INTEGRATED STORAGE UNLOCKED"
        case .manifestationFieldCharged:
            return "VEIL INSTABILITY RISING"
        case .awakenedHunt:
            return "EXTRACT 3 UNSTABLE SIGNALS"
        case .manifestationDetected:
            return "BEGIN RESONANCE ANALYSIS"
        case .entityCatalogued:
            return nil
        case .libraryUpdated:
            return nil
        }
    }
}
