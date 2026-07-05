import Foundation

struct ResonanceLockTracker {
    private(set) var state = ResonanceLockState.idle

    let lockDecayDuration: TimeInterval
    let beamDuration: TimeInterval

    init(
        lockDecayDuration: TimeInterval = ResonanceTiming.lockDecayDuration,
        beamDuration: TimeInterval = ResonanceTiming.beamDuration
    ) {
        self.lockDecayDuration = lockDecayDuration
        self.beamDuration = beamDuration
    }

    mutating func update(
        contactTargetID: UUID?,
        deltaTime: TimeInterval,
        lockDuration: TimeInterval
    ) -> ResonanceLockUpdate {
        let delta = max(deltaTime, 0)

        guard let contactTargetID else {
            return decay(deltaTime: delta)
        }

        if state.targetID != contactTargetID {
            state = ResonanceLockState(targetID: contactTargetID, hasContact: true)
        } else {
            state.hasContact = true
        }

        let previousLockProgress = state.lockProgress
        let previousBeamProgress = state.beamProgress

        if state.lockProgress < 1 {
            state.lockProgress = min(
                state.lockProgress + delta / max(lockDuration, 0.001),
                1
            )
        } else {
            state.beamProgress = min(
                state.beamProgress + delta / max(beamDuration, 0.001),
                1
            )
        }

        return ResonanceLockUpdate(
            state: state,
            didAcquireLock: previousLockProgress < 1 && state.lockProgress >= 1,
            didCompleteBeam: previousBeamProgress < 1 && state.beamProgress >= 1
        )
    }

    mutating func forceLock(targetID: UUID) -> ResonanceLockUpdate {
        state = ResonanceLockState(
            targetID: targetID,
            lockProgress: 1,
            beamProgress: 0,
            hasContact: true
        )
        return ResonanceLockUpdate(
            state: state,
            didAcquireLock: true,
            didCompleteBeam: false
        )
    }

    mutating func reset() {
        state = .idle
    }

    private mutating func decay(deltaTime: TimeInterval) -> ResonanceLockUpdate {
        guard state.targetID != nil else {
            return ResonanceLockUpdate(
                state: state,
                didAcquireLock: false,
                didCompleteBeam: false
            )
        }

        state.hasContact = false
        state.lockProgress = max(
            state.lockProgress - deltaTime / max(lockDecayDuration, 0.001),
            0
        )
        state.beamProgress = max(
            state.beamProgress - deltaTime / max(beamDuration, 0.001),
            0
        )

        if state.lockProgress == 0 && state.beamProgress == 0 {
            state = .idle
        }

        return ResonanceLockUpdate(
            state: state,
            didAcquireLock: false,
            didCompleteBeam: false
        )
    }
}
