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

enum ScannerGameplayPhase: Equatable {
    case calmSearch
    case charged
    case overloading
    case awakenedHunt
    case manifestation
}

enum ScannerNotice: Equatable {
    case essenceContained
    case capacitorCharged
    case containmentCellCrafted
    case overloading
    case awakenedHunt
    case synchronizing
    case entityCatalogued
    case libraryUpdated
}

@MainActor
final class ARScannerViewModel: ObservableObject {
    private static let wispIdentificationKey = "veilogy.willOTheWisp.identified"

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
    @Published private(set) var overloadEventCounter = 0
    @Published private(set) var gameplayPhase: ScannerGameplayPhase = .calmSearch
    @Published private(set) var awakenedContainedCount = 0
    @Published private(set) var overloadStartedAt: Date?
    @Published private(set) var essenceFieldRevision = 0
    @Published private(set) var hasIdentifiedWisp = false
    #if DEBUG
    @Published private(set) var debugAutoLockEnabled = false
    @Published private(set) var debugShowPlanes = false
    @Published private(set) var debugPlaneClassificationSupported = false
    @Published private(set) var debugFloorPlaneCount = 0
    @Published private(set) var debugWallPlaneCount = 0
    @Published private(set) var debugTablePlaneCount = 0
    @Published private(set) var debugOtherPlaneCount = 0
    @Published private(set) var debugTraversalEventCounter = 0
    @Published private(set) var debugTraversalStatus = "READY"
    #endif

    private var startupBeganAt: CFTimeInterval?
    private var noticeTask: Task<Void, Never>?
    private var overloadTask: Task<Void, Never>?
    private let bootDuration: CFTimeInterval = 2.4
    private let lensEngagementDuration: CFTimeInterval = 1
    let calmContainmentGoal = 5
    let awakenedContainmentGoal = 3

    @MainActor
    init() {
        self.scannerStateStore = ARScannerStateStore()
        self.inventoryStore = EssenceInventoryStore()
        self.visibleEssenceStore = VisibleEssenceStore()
        self.lostSoulStore = LostSoulStore()
        self.essenceFactory = AmbientEssenceFactory()
        self.hasIdentifiedWisp = UserDefaults.standard.bool(forKey: Self.wispIdentificationKey)

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
        self.hasIdentifiedWisp = UserDefaults.standard.bool(forKey: Self.wispIdentificationKey)

        prepareScannerField()
    }

    var visibleEssences: [AmbientEssence] {
        visibleEssenceStore.visibleEssences
    }

    var isScannerActive: Bool {
        startupPhase == .active
    }

    var canContainEssence: Bool {
        gameplayPhase == .calmSearch || gameplayPhase == .awakenedHunt
    }

    var displayedContainedCount: Int {
        min(inventoryStore.capacitorEssenceCount, calmContainmentGoal)
    }

    var displayedContainmentGoal: Int {
        calmContainmentGoal
    }

    var counterLabel: String {
        AppStrings.essenceCounterLabel
    }

    var noticeContainedCount: Int {
        gameplayPhase == .manifestation
            ? awakenedContainedCount
            : displayedContainedCount
    }

    var noticeRequiredCount: Int {
        gameplayPhase == .manifestation
            ? awakenedContainmentGoal
            : calmContainmentGoal
    }

    var fieldCounterLabel: String {
        switch gameplayPhase {
        case .calmSearch:
            return "FIELD"
        case .charged:
            return "DORMANT"
        case .overloading:
            return "RELEASING"
        case .awakenedHunt:
            return "ACTIVE"
        case .manifestation:
            return "RESONANCE"
        }
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
        guard canContainEssence else {
            return false
        }

        guard let essence = visibleEssenceStore.remove(id: id) else {
            return false
        }

        clearLockOn()
        inventoryStore.collect(essence)

        switch gameplayPhase {
        case .calmSearch:
            if inventoryStore.capacitorEssenceCount >= calmContainmentGoal {
                gameplayPhase = .charged
                scannerStateStore.setStatus(.charged)
            }
            presentContainmentFeedback()

        case .awakenedHunt:
            awakenedContainedCount += essence.value
            if awakenedContainedCount >= awakenedContainmentGoal {
                gameplayPhase = .manifestation
                scannerStateStore.setStatus(.lostSoulManifested)
            }
            presentContainmentFeedback()

        case .charged, .overloading, .manifestation:
            return false
        }

        if gameplayPhase == .manifestation {
            hasIdentifiedWisp = true
            UserDefaults.standard.set(true, forKey: Self.wispIdentificationKey)
            lostSoulStore.manifest(LostSoul(id: UUID()))
        }

        return true
    }

    func activateOverload() {
        guard
            gameplayPhase == .charged,
            inventoryStore.spend(calmContainmentGoal)
        else {
            return
        }

        noticeTask?.cancel()
        overloadTask?.cancel()
        clearLockOn()
        gameplayPhase = .overloading
        scannerStateStore.setStatus(.overloading)
        scannerNotice = .overloading
        overloadStartedAt = Date()
        overloadEventCounter += 1

        overloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 1_250) else { return }

            gameplayPhase = .awakenedHunt
            scannerStateStore.setStatus(.hunting)
            scannerNotice = .awakenedHunt
            guard await wait(milliseconds: 1_100) else { return }
            scannerNotice = nil
        }
    }

    func craftContainmentCell() {
        guard
            gameplayPhase == .charged,
            inventoryStore.craftContainmentCell(cost: calmContainmentGoal)
        else {
            return
        }

        noticeTask?.cancel()
        overloadTask?.cancel()
        clearLockOn()
        scannerNotice = .containmentCellCrafted
        containmentEventCounter += 1
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        lostSoulStore.clear()
        awakenedContainedCount = 0
        gameplayPhase = .calmSearch
        scannerStateStore.setStatus(.scanning)
        essenceFieldRevision += 1

        noticeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 1_500) else { return }
            scannerNotice = nil
        }
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

    #if DEBUG
    func setDebugAutoLockEnabled(_ enabled: Bool) {
        debugAutoLockEnabled = enabled
        if !enabled {
            clearLockOn()
        }
    }

    func setDebugShowPlanes(_ enabled: Bool) {
        debugShowPlanes = enabled
    }

    func updateDebugPlaneClassifications(
        isSupported: Bool,
        floor: Int,
        wall: Int,
        table: Int,
        other: Int
    ) {
        if debugPlaneClassificationSupported != isSupported {
            debugPlaneClassificationSupported = isSupported
        }
        if debugFloorPlaneCount != floor {
            debugFloorPlaneCount = floor
        }
        if debugWallPlaneCount != wall {
            debugWallPlaneCount = wall
        }
        if debugTablePlaneCount != table {
            debugTablePlaneCount = table
        }
        if debugOtherPlaneCount != other {
            debugOtherPlaneCount = other
        }
    }

    func requestDebugSurfaceTraversal() {
        debugTraversalStatus = "SEARCHING"
        debugTraversalEventCounter += 1
    }

    func setDebugTraversalStatus(_ status: String) {
        debugTraversalStatus = status
    }
    #endif

    private func prepareScannerField() {
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        lostSoulStore.clear()
        gameplayPhase = .calmSearch
        awakenedContainedCount = 0
        overloadStartedAt = nil
        scannerStateStore.setStatus(.scanning)
    }

    private func presentContainmentFeedback() {
        containmentEventCounter += 1
        scannerNotice = .essenceContained
        noticeTask?.cancel()

        noticeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 900) else { return }

            if gameplayPhase == .charged {
                scannerNotice = .capacitorCharged
                guard await wait(milliseconds: 1_350) else { return }
                scannerNotice = nil
                return
            }

            guard gameplayPhase == .manifestation else {
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
