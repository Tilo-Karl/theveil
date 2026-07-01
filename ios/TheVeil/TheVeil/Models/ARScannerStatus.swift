import Foundation

enum ARScannerStatus: Equatable {
    case initializing
    case scanning
    case charged
    case overloading
    case hunting
    case lostSoulManifested
    case unavailable
}
