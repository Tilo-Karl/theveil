import Foundation

enum ARScannerStatus: Equatable {
    case initializing
    case scanning
    case charged
    case discharging
    case hunting
    case minorSpecterManifested
    case unavailable
}
