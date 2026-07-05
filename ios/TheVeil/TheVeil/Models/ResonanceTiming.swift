import Foundation

enum ResonanceTiming {
    static let lockDuration: TimeInterval = 2.5
    static let beamDuration: TimeInterval = 2
    static let lockDecayDuration: TimeInterval = 4
    static let reactionGraceDuration: TimeInterval = 0.75

    static let minimumCaptureWindow = lockDuration
        + beamDuration
        + reactionGraceDuration
}
