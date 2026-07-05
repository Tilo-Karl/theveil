import Foundation

struct DischargeCircuitState: Equatable, Sendable {
    var isActive = false
    var intensity = 1
    var packetProgress: Double = 0
    var packetDuration: TimeInterval = 2
}

enum DischargeCircuitStopReason: Equatable, Sendable {
    case playerStopped
    case capacitorEmpty
    case encounterThresholdReached
}
