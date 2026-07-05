import Foundation

struct ResonanceLockState: Equatable, Sendable {
    var targetID: UUID?
    var lockProgress: Double = 0
    var beamProgress: Double = 0
    var hasContact = false

    var isBeamActive: Bool {
        targetID != nil && hasContact && lockProgress >= 1
    }

    static let idle = ResonanceLockState()
}

struct ResonanceLockUpdate: Equatable, Sendable {
    let state: ResonanceLockState
    let didAcquireLock: Bool
    let didCompleteBeam: Bool
}
