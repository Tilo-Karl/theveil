import Foundation

enum AppStrings {
    static let scannerTitle = "The Veil"
    static let scannerModeLabel = "VEIL SCANNER"
    static let scannerSignalLabel = "SPECTRAL RESONANCE"
    static let essenceCounterLabel = "VEIL CAPACITOR"
    static let ambientEssenceLabel = "Collected"
    static let visibleEssenceLabel = "Remaining"
    static let scannerUnavailableTitle = "AR scanner unavailable"
    static let scannerUnavailableMessage = "Open The Veil on an ARKit-capable device to scan for ambient essence."
    static let collectingHint = "Move close and aim at essence to collect it."
    static let lostSoulHint = "Hold the reticle on the Lost Soul."
    static let cameraUsageDescription = "The Veil uses the camera to scan your surroundings for ambient spirit essence."

    static func scannerStatusText(_ status: ARScannerStatus) -> String {
        switch status {
        case .initializing:
            return "Opening scanner"
        case .scanning:
            return "Scanning for ambient essence"
        case .charged:
            return "Containment cells charged"
        case .overloading:
            return "Discharging containment array"
        case .hunting:
            return "Tracking agitated essence"
        case .lostSoulManifested:
            return "Lost Soul manifested"
        case .unavailable:
            return scannerUnavailableTitle
        }
    }

    static func scannerHintText(_ status: ARScannerStatus) -> String {
        switch status {
        case .lostSoulManifested:
            return lostSoulHint
        case .initializing, .scanning, .charged, .overloading, .hunting, .unavailable:
            return collectingHint
        }
    }
}
