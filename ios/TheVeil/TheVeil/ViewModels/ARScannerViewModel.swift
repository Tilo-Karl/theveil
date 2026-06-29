import Combine
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

enum ScannerNotice: Equatable {
    case essenceContained
    case synchronizing
    case entityCatalogued
    case libraryUpdated
}

@MainActor
final class ARScannerViewModel: ObservableObject {
    let scannerStateStore: ARScannerStateStore
    let inventoryStore: EssenceInventoryStore
    let visibleEssenceStore: VisibleEssenceStore
    let lostSoulStore: LostSoulStore

    private let essenceFactory: AmbientEssenceFactory

    @Published private(set) var lockOnProgress: Double = 0
    @Published private(set) var lockOnTargetID: UUID?
    @Published private(set) var startupPhase: ScannerStartupPhase = .booting
    @Published private(set) var lensIntensity: Float = 0
    @Published private(set) var signalMode: ScannerSignalMode = .passive
    @Published private(set) var signalStrength: Double = 0.08
    @Published private(set) var scannerNotice: ScannerNotice?
    @Published private(set) var detectionEventCounter = 0
    @Published private(set) var containmentEventCounter = 0

    private var startupBeganAt: CFTimeInterval?
    private var noticeTask: Task<Void, Never>?
    private let bootDuration: CFTimeInterval = 2.4
    private let lensEngagementDuration: CFTimeInterval = 1

    @MainActor
    init() {
        self.scannerStateStore = ARScannerStateStore()
        self.inventoryStore = EssenceInventoryStore()
        self.visibleEssenceStore = VisibleEssenceStore()
        self.lostSoulStore = LostSoulStore()
        self.essenceFactory = AmbientEssenceFactory()

        prepareScannerField()
    }

    @MainActor
    init(
        scannerStateStore: ARScannerStateStore,
        inventoryStore: EssenceInventoryStore,
        visibleEssenceStore: VisibleEssenceStore,
        lostSoulStore: LostSoulStore,
        essenceFactory: AmbientEssenceFactory
    ) {
        self.scannerStateStore = scannerStateStore
        self.inventoryStore = inventoryStore
        self.visibleEssenceStore = visibleEssenceStore
        self.lostSoulStore = lostSoulStore
        self.essenceFactory = essenceFactory

        prepareScannerField()
    }

    var visibleEssences: [AmbientEssence] {
        visibleEssenceStore.visibleEssences
    }

    var isScannerActive: Bool {
        startupPhase == .active
    }

    func updateScannerStartup(at time: CFTimeInterval) {
        if startupBeganAt == nil {
            startupBeganAt = time
        }

        let elapsed = time - (startupBeganAt ?? time)
        let nextPhase: ScannerStartupPhase
        let nextLensIntensity: Float

        if elapsed < bootDuration {
            nextPhase = .booting
            nextLensIntensity = 0
        } else if elapsed < bootDuration + lensEngagementDuration {
            nextPhase = .engagingLens
            nextLensIntensity = Float((elapsed - bootDuration) / lensEngagementDuration)
        } else {
            nextPhase = .active
            nextLensIntensity = 1
        }

        if startupPhase != nextPhase {
            startupPhase = nextPhase
        }
        if abs(lensIntensity - nextLensIntensity) > 0.002 {
            lensIntensity = nextLensIntensity
        }
    }

    func markScannerUnavailable() {
        scannerStateStore.setStatus(.unavailable)
        visibleEssenceStore.replace(with: [])
        lostSoulStore.clear()
    }

    func collectEssence(id: AmbientEssence.ID) -> Bool {
        guard let essence = visibleEssenceStore.remove(id: id) else {
            return false
        }

        clearLockOn()
        inventoryStore.collect(essence)
        presentContainmentFeedback()

        if visibleEssenceStore.visibleEssenceCount == 0 {
            lostSoulStore.manifest(LostSoul(id: UUID()))
            scannerStateStore.setStatus(.lostSoulManifested)
        }

        return true
    }

    func updateSpectralSignal(
        strength: Double,
        anomalyDetected: Bool,
        lockProgress: Double?
    ) {
        let clampedStrength = min(max(strength, 0.04), 1)
        let smoothedStrength = signalStrength * 0.78 + clampedStrength * 0.22
        if abs(signalStrength - smoothedStrength) > 0.002 {
            signalStrength = smoothedStrength
        }

        let nextMode: ScannerSignalMode
        if lockProgress != nil {
            nextMode = .locking
        } else if anomalyDetected {
            nextMode = .anomalyDetected
        } else {
            nextMode = .passive
        }

        if signalMode == .passive && nextMode != .passive {
            detectionEventCounter += 1
        }
        if signalMode != nextMode {
            signalMode = nextMode
        }
    }

    func updateLockOn(targetID: UUID?, progress: Double) {
        lockOnTargetID = targetID
        lockOnProgress = min(max(progress, 0), 1)
    }

    func clearLockOn() {
        lockOnTargetID = nil
        lockOnProgress = 0
    }

    private func prepareScannerField() {
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        lostSoulStore.clear()
        scannerStateStore.setStatus(.scanning)
    }

    private func presentContainmentFeedback() {
        containmentEventCounter += 1
        scannerNotice = .essenceContained
        noticeTask?.cancel()

        let requiredCount = inventoryStore.ambientEssenceCount
            + visibleEssenceStore.visibleEssenceCount
        let hasCompleteSampleSet = inventoryStore.ambientEssenceCount >= requiredCount

        noticeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 900) else { return }

            guard hasCompleteSampleSet else {
                scannerNotice = nil
                return
            }

            scannerNotice = .synchronizing
            guard await wait(milliseconds: 1_250) else { return }
            scannerNotice = .entityCatalogued
            guard await wait(milliseconds: 1_150) else { return }
            scannerNotice = .libraryUpdated
            guard await wait(milliseconds: 1_150) else { return }
            scannerNotice = nil
        }
    }

    private func wait(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return true
        } catch {
            return false
        }
    }
}
