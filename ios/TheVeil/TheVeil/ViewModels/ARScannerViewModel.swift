import Combine
import Foundation

@MainActor
final class ARScannerViewModel: ObservableObject {
    let scannerStateStore: ARScannerStateStore
    let inventoryStore: EssenceInventoryStore
    let researchStore: WispResearchStore
    let visibleEssenceStore: VisibleEssenceStore
    let lostSoulStore: LostSoulStore
    let specterStore: SpecterStore
    let encounterStore: ManifestationEncounterStore
    let dischargeCircuitStore: DischargeCircuitStore

    private let essenceFactory: AmbientEssenceFactory
    let dischargeCircuitOrchestrator: DischargeCircuitOrchestrator

    @Published private(set) var lockOnProgress: Double = 0
    @Published private(set) var lockOnTargetID: UUID?
    @Published private(set) var resonanceBeamProgress: Double = 0
    @Published private(set) var resonanceBeamActive = false
    @Published private(set) var startupPhase: ScannerStartupPhase = .booting
    @Published private(set) var lensIntensity: Float = 0
    @Published private(set) var signalMode: ScannerSignalMode = .passive
    @Published private(set) var signalStrength: Double = 0.08
    @Published var scannerNotice: ScannerNotice?
    @Published private(set) var detectionEventCounter = 0
    @Published var essenceStorageEventCounter = 0
    @Published var manifestationPulseEventCounter = 0
    @Published var megaBeamEventCounter = 0
    @Published var megaBeamStartedAt: Date?
    @Published var megaBeamPeakCharge = 0
    @Published var megaBeamIntensity: Double = 0
    @Published var gameplayPhase: ScannerGameplayPhase = .calmSearch
    @Published private(set) var awakenedExtractionCount = 0
    @Published var manifestationPulseStartedAt: Date?
    @Published var essenceFieldRevision = 0
    #if DEBUG
    @Published private(set) var debugAutoLockEnabled = false
    @Published private(set) var debugPhaseCubeEnabled = false
    @Published private(set) var debugTraversalStatus = "READY"
    #endif

    private var startupBeganAt: CFTimeInterval?
    private var latestCameraPosition = SIMD3<Float>.zero
    private var latestCameraForward = SIMD3<Float>(0, 0, -1)
    var noticeTask: Task<Void, Never>?
    var manifestationTransitionTask: Task<Void, Never>?
    var resupplyTask: Task<Void, Never>?
    private let bootDuration: CFTimeInterval = 2.4
    private let lensEngagementDuration: CFTimeInterval = 1
    let resupplyDuration: Duration = .seconds(24)
    let awakenedExtractionGoal = 3

    @MainActor
    init() {
        let inventoryStore = EssenceInventoryStore()
        let dischargeCircuitStore = DischargeCircuitStore()

        self.scannerStateStore = ARScannerStateStore()
        self.inventoryStore = inventoryStore
        self.researchStore = WispResearchStore()
        self.visibleEssenceStore = VisibleEssenceStore()
        self.lostSoulStore = LostSoulStore()
        self.specterStore = SpecterStore()
        self.encounterStore = ManifestationEncounterStore()
        self.dischargeCircuitStore = dischargeCircuitStore
        self.essenceFactory = AmbientEssenceFactory()
        self.dischargeCircuitOrchestrator = DischargeCircuitOrchestrator(
            inventoryStore: inventoryStore,
            circuitStore: dischargeCircuitStore
        )

        synchronizeResearchUnlocks()
        prepareScannerField()
    }

    @MainActor
    init(
        scannerStateStore: ARScannerStateStore,
        inventoryStore: EssenceInventoryStore,
        researchStore: WispResearchStore,
        visibleEssenceStore: VisibleEssenceStore,
        lostSoulStore: LostSoulStore,
        specterStore: SpecterStore,
        encounterStore: ManifestationEncounterStore,
        dischargeCircuitStore: DischargeCircuitStore,
        essenceFactory: AmbientEssenceFactory
    ) {
        self.scannerStateStore = scannerStateStore
        self.inventoryStore = inventoryStore
        self.researchStore = researchStore
        self.visibleEssenceStore = visibleEssenceStore
        self.lostSoulStore = lostSoulStore
        self.specterStore = specterStore
        self.encounterStore = encounterStore
        self.dischargeCircuitStore = dischargeCircuitStore
        self.essenceFactory = essenceFactory
        self.dischargeCircuitOrchestrator = DischargeCircuitOrchestrator(
            inventoryStore: inventoryStore,
            circuitStore: dischargeCircuitStore
        )

        synchronizeResearchUnlocks()
        prepareScannerField()
    }

    var visibleEssences: [AmbientEssence] {
        visibleEssenceStore.visibleEssences
    }

    var isScannerActive: Bool {
        startupPhase == .active
    }

    var canExtractEssence: Bool {
        megaBeamStartedAt == nil
            && (gameplayPhase == .calmSearch || gameplayPhase == .awakenedHunt)
    }

    var canOperateCapacitor: Bool {
        isScannerActive && megaBeamStartedAt == nil
    }

    var canManageCapacitorStorage: Bool {
        !dischargeCircuitStore.isActive
            && (gameplayPhase == .calmSearch || gameplayPhase == .charged)
    }

    var hasIdentifiedWisp: Bool {
        researchStore.hasIdentifiedWisp
    }

    var displayedCapacitorCapacity: Int {
        inventoryStore.equipment.capacitorCapacity
    }

    var displayedContainmentCellCapacity: Int {
        inventoryStore.equipment.containmentCellCapacity
    }

    var canActivateContainmentCell: Bool {
        isScannerActive
            && inventoryStore.isIntegratedCellUnlocked
            && inventoryStore.containmentCellEssenceCount > 0
            && megaBeamStartedAt == nil
    }

    var counterLabel: String {
        AppStrings.essenceCounterLabel
    }

    var fieldCounterLabel: String {
        if encounterStore.state.phase == .chargingField {
            return AppStrings.manifestationCounterLabel
        }
        switch gameplayPhase {
        case .calmSearch:
            return AppStrings.fieldCounterLabel
        case .charged:
            return AppStrings.dormantCounterLabel
        case .discharging:
            return AppStrings.releasingCounterLabel
        case .awakenedHunt:
            return AppStrings.resupplyCounterLabel
        case .manifestation:
            return AppStrings.resonanceCounterLabel
        }
    }

    var fieldCounterValue: String {
        if encounterStore.state.phase == .chargingField {
            return "\(AppStrings.resonanceValue(encounterStore.fieldCharge)) / \(AppStrings.resonanceValue(encounterStore.requiredFieldCharge))"
        }
        if gameplayPhase == .awakenedHunt {
            return "\(awakenedExtractionCount) / \(awakenedExtractionGoal)"
        }
        if
            encounterStore.state.phase == .manifested,
            let profile = encounterStore.state.entityProfile
        {
            return "\(AppStrings.resonanceValue(encounterStore.targetResonance)) / \(AppStrings.resonanceValue(profile.stability))"
        }
        return "\(visibleEssenceStore.visibleEssenceCount)"
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

    func updateScannerPose(position: SIMD3<Float>, forward: SIMD3<Float>) {
        latestCameraPosition = position
        latestCameraForward = forward
    }

    func makeAgitatedResupplyField() -> [AmbientEssence] {
        essenceFactory.makeResupplyField(
            cameraPosition: latestCameraPosition,
            cameraForward: latestCameraForward
        )
    }

    func markScannerUnavailable() {
        scannerStateStore.setStatus(.unavailable)
        visibleEssenceStore.replace(with: [])
        lostSoulStore.clear()
        specterStore.clear()
    }

    func collectEssence(id: AmbientEssence.ID) -> Bool {
        guard canExtractEssence else {
            return false
        }

        guard
            let essence = visibleEssenceStore.visibleEssences.first(where: { $0.id == id }),
            inventoryStore.canCollect(essence),
            inventoryStore.collect(essence),
            visibleEssenceStore.remove(id: id) != nil
        else {
            return false
        }

        clearLockOn()

        switch gameplayPhase {
        case .calmSearch:
            if inventoryStore.capacitorEssenceCount == inventoryStore.equipment.capacitorCapacity {
                gameplayPhase = .charged
                scannerStateStore.setStatus(.charged)
            }
            presentExtractionFeedback()

        case .awakenedHunt:
            awakenedExtractionCount += essence.value
            presentExtractionFeedback()

        case .charged, .discharging, .manifestation:
            return false
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

    func updateResonanceLock(_ state: ResonanceLockState) {
        lockOnTargetID = state.targetID
        lockOnProgress = min(max(state.lockProgress, 0), 1)
        resonanceBeamProgress = min(max(state.beamProgress, 0), 1)
        resonanceBeamActive = state.isBeamActive
    }

    func clearLockOn() {
        lockOnTargetID = nil
        lockOnProgress = 0
        resonanceBeamProgress = 0
        resonanceBeamActive = false
    }

    #if DEBUG
    func setDebugAutoLockEnabled(_ enabled: Bool) {
        debugAutoLockEnabled = enabled
        if !enabled {
            clearLockOn()
        }
    }

    func setDebugPhaseCubeEnabled(_ enabled: Bool) {
        debugPhaseCubeEnabled = enabled
        debugTraversalStatus = enabled ? "STARTING" : "READY"
    }

    func setDebugTraversalStatus(_ status: String) {
        if debugTraversalStatus != status {
            debugTraversalStatus = status
        }
    }
    #endif

    private func synchronizeResearchUnlocks() {
        if researchStore.hasIdentifiedWisp {
            inventoryStore.unlockIntegratedCell()
        }
    }

    private func prepareScannerField() {
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        lostSoulStore.clear()
        specterStore.clear()
        encounterStore.reset()
        gameplayPhase = .calmSearch
        awakenedExtractionCount = 0
        manifestationPulseStartedAt = nil
        scannerStateStore.setStatus(.scanning)
    }

    func beginFreshCalmSearch() {
        noticeTask?.cancel()
        manifestationTransitionTask?.cancel()
        clearLockOn()
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        lostSoulStore.clear()
        specterStore.clear()
        awakenedExtractionCount = 0
        gameplayPhase = inventoryStore.capacitorEssenceCount == inventoryStore.equipment.capacitorCapacity
            ? .charged
            : .calmSearch
        scannerStateStore.setStatus(gameplayPhase == .charged ? .charged : .scanning)
        manifestationPulseStartedAt = nil
        essenceFieldRevision += 1
    }

    private func presentExtractionFeedback() {
        essenceStorageEventCounter += 1
        scannerNotice = .essenceStored(
            capacitorCharge: inventoryStore.capacitorEssenceCount,
            capacitorCapacity: inventoryStore.equipment.capacitorCapacity
        )
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

            scannerNotice = .manifestationDetected
            guard await wait(milliseconds: 1_500) else { return }
            scannerNotice = nil
        }
    }

    func presentUploadFeedback(
        samples: Int,
        result: WispResearchUploadResult
    ) {
        noticeTask?.cancel()
        scannerNotice = .essenceUploaded(samples: samples)

        noticeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 900) else { return }

            switch result {
            case .noSamples:
                scannerNotice = .capacitorEmpty

            case .progress(let current, let required):
                scannerNotice = .researchProgress(current: current, required: required)

            case .identified:
                scannerNotice = .entityCatalogued
                guard await wait(milliseconds: 1_100) else { return }
                scannerNotice = .containmentCellUnlocked
                guard await wait(milliseconds: 1_100) else { return }
                scannerNotice = .libraryUpdated

            case .contributed:
                scannerNotice = .libraryUpdated
            }

            guard await wait(milliseconds: 1_350) else { return }
            scannerNotice = nil
        }
    }

    func presentBriefNotice(
        _ notice: ScannerNotice,
        milliseconds: Int = 1_200
    ) {
        noticeTask?.cancel()
        scannerNotice = notice
        noticeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: milliseconds) else { return }
            scannerNotice = nil
        }
    }

    func wait(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return true
        } catch {
            return false
        }
    }
}
