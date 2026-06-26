import Foundation

enum AppStrings {
    static let scannerTitle = "The Veil"
    static let ambientEssenceLabel = "Ambient Essence"
    static let visibleEssenceLabel = "Visible"
    static let scannerUnavailableTitle = "AR scanner unavailable"
    static let scannerUnavailableMessage = "Open The Veil on an ARKit-capable device to scan for ambient essence."
    static let collectingHint = "Tap a glowing essence to collect it."
    static let cameraUsageDescription = "The Veil uses the camera to scan your surroundings for ambient spirit essence."

    static func scannerStatusText(_ status: ARScannerStatus) -> String {
        switch status {
        case .initializing:
            return "Opening scanner"
        case .scanning:
            return "Scanning for ambient essence"
        case .fieldCleared:
            return "Ambient essence collected"
        case .unavailable:
            return scannerUnavailableTitle
        }
    }
}
