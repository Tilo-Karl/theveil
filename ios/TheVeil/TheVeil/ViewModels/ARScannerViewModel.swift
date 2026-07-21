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
    let ectoStore: EctoStore
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
    @Published private(set) var scannerIntegrity = 100
    @Published private(set) var combatFeedback: SpecterCombatFeedback?
    @Published private(set) var combatFeedbackEventCounter = 0
    @Published private(set) var combatFeedbackStartedAt: Date?
    @Published private(set) var scannerFailsafeStartedAt: Date?
    #if DEBUG
    @Published private(set) var debugAutoLockEnabled = false
    @Published private(set) var debugPhaseCubeEnabled = false
    @Published private(set) var debugTraversalStatus = "READY"
    @Published private(set) var debugEctoStatus = "ECTO READY"
    @Published private(set) var debugEctoSpawnEventCounter = 0
    #endif

    private var startupBeganAt: CFTimeInterval?
    private var latestCameraPosition = SIMD3<Float>.zero
    private var latestCameraForward = SIMD3<Float>(0, 0, -1)
    var noticeTask: Task<Void, Never>?
    var manifestationTransitionTask: Task<Void, Never>?
    var resupplyTask: Task<Void, Never>?
    var overloadPulseTask: Task<Void, Never>?
    var cellFeedTask: Task<Void, Never>?
    private var combatFeedbackTask: Task<Void, Never>?
    private var scannerRepairTask: Task<Void, Never>?
    private let bootDuration: CFTimeInterval = 2.4
    private let lensEngagementDuration: CFTimeInterval = 1
    let resupplyDuration: Duration = .seconds(24)
    let awakenedExtractionGoal = 3
    let scannerIntegrityCapacity = 100
    private let scannerIntegrityDamagePerHit = 34
    let scannerFailsafeDuration: TimeInterval = 7

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
        self.ectoStore = EctoStore()
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
        ectoStore: EctoStore,
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
        self.ectoStore = ectoStore
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

    var isScannerOperational: Bool {
        isScannerActive && scannerFailsafeStartedAt == nil
    }

    var canExtractEssence: Bool {
        megaBeamStartedAt == nil
            && scannerFailsafeStartedAt == nil
            && (gameplayPhase == .calmSearch || gameplayPhase == .awakenedHunt)
    }

    var canOperateCapacitor: Bool {
        isScannerOperational && megaBeamStartedAt == nil
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

    var canDischargeCapacitor: Bool {
        if dischargeCircuitStore.isActive {
            return true
        }
        guard inventoryStore.capacitorEssenceCount > 0 else {
            return false
        }
        guard encounterStore.state.phase == .manifested else {
            return isScannerOperational
        }
        return isScannerOperational && resonanceBeamActive
    }

    var canOverloadCapacitor: Bool {
        inventoryStore.capacitorEssenceCount >= inventoryStore.equipment.capacitorCapacity
            && encounterStore.state.phase == .manifested
            && isScannerOperational
            && resonanceBeamActive
            && megaBeamStartedAt == nil
            && !dischargeCircuitStore.isActive
    }

    var counterLabel: String {
        AppStrings.essenceCounterLabel
    }

    var fieldCounterLabel: String {
        if ectoStore.activeEcto != nil {
            return AppStrings.integrityCounterLabel
        }
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
            return AppStrings.integrityCounterLabel
        }
    }

    var fieldCounterValue: String {
        if ectoStore.activeEcto != nil {
            return "\(AppStrings.resonanceValue(ectoStore.ectoplasmicDamage)) / \(AppStrings.resonanceValue(Ecto.ectoplasmicIntegrity))"
        }
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
            return "\(AppStrings.resonanceValue(encounterStore.ectoplasmicDamage)) / \(AppStrings.resonanceValue(profile.ectoplasmicIntegrity))"
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
        ectoStore.clear()
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

    func spawnEcto(_ ecto: Ecto) {
        ectoStore.spawn(ecto)
        #if DEBUG
        debugEctoStatus = "ECTO ACTIVE"
        #endif
    }

    #if DEBUG
    func spawnDebugEcto(_ ecto: Ecto) {
        spawnEcto(ecto)
    }
    #endif

    func zapEcto(id: Ecto.ID) -> Bool {
        guard isScannerOperational else {
            return false
        }

        let result = ectoStore.applyScannerZap(id: id)
        switch result {
        case .noEffect:
            return false

        case .progressed(let current, let required):
            scannerNotice = .ectoIntegrityDamaged(current: current, required: required)
            noticeTask?.cancel()
            noticeTask = Task { @MainActor [weak self] in
                guard let self else { return }
                guard await wait(milliseconds: 650) else { return }
                if case .ectoIntegrityDamaged = scannerNotice {
                    scannerNotice = nil
                }
            }
            return false

        case .thresholdReached(let ecto):
            clearLockOn()

            if inventoryStore.collectEctoSample(value: ecto.essenceValue) {
                if inventoryStore.capacitorEssenceCount == inventoryStore.equipment.capacitorCapacity {
                    gameplayPhase = .charged
                    scannerStateStore.setStatus(.charged)
                }

                essenceStorageEventCounter += 1
                scannerNotice = .ectoSampleStored(
                    capacitorCharge: inventoryStore.capacitorEssenceCount,
                    capacitorCapacity: inventoryStore.equipment.capacitorCapacity
                )
                noticeTask?.cancel()
                noticeTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard await wait(milliseconds: 1_050) else { return }

                    if gameplayPhase == .charged {
                        scannerNotice = .capacitorCharged
                        guard await wait(milliseconds: 1_350) else { return }
                    }
                    scannerNotice = nil
                }
            } else {
                presentBriefNotice(.capacitorCharged, milliseconds: 900)
            }

            #if DEBUG
            debugEctoStatus = "ECTO READY"
            #endif

            return true
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

    func handleSpecterCombatEvent(_ event: SpecterCombatEvent) {
        guard
            gameplayPhase == .manifestation,
            encounterStore.state.phase == .manifested,
            scannerFailsafeStartedAt == nil
        else {
            return
        }

        switch event {
        case .attackTelegraph, .boltFired:
            presentCombatFeedback(.incoming, milliseconds: 900)

        case .boltDodged:
            presentCombatFeedback(.dodged, milliseconds: 850)

        case .boltHit:
            scannerIntegrity = max(
                scannerIntegrity - scannerIntegrityDamagePerHit,
                0
            )
            if scannerIntegrity <= 0 {
                triggerScannerFailsafe()
            } else {
                presentCombatFeedback(.hit, milliseconds: 1_050)
            }
        }
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

    func requestDebugEctoSpawn() {
        debugEctoSpawnEventCounter += 1
        debugEctoStatus = "SPAWNING"
    }

    func setDebugEctoStatus(_ status: String) {
        if debugEctoStatus != status {
            debugEctoStatus = status
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
        ectoStore.clear()
        encounterStore.reset()
        gameplayPhase = .calmSearch
        awakenedExtractionCount = 0
        manifestationPulseStartedAt = nil
        overloadPulseTask?.cancel()
        cellFeedTask?.cancel()
        megaBeamStartedAt = nil
        scannerIntegrity = scannerIntegrityCapacity
        combatFeedback = nil
        scannerFailsafeStartedAt = nil
        scannerStateStore.setStatus(.scanning)
    }

    func beginFreshCalmSearch() {
        noticeTask?.cancel()
        manifestationTransitionTask?.cancel()
        clearLockOn()
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        lostSoulStore.clear()
        specterStore.clear()
        ectoStore.clear()
        awakenedExtractionCount = 0
        gameplayPhase = inventoryStore.capacitorEssenceCount == inventoryStore.equipment.capacitorCapacity
            ? .charged
            : .calmSearch
        scannerStateStore.setStatus(gameplayPhase == .charged ? .charged : .scanning)
        manifestationPulseStartedAt = nil
        overloadPulseTask?.cancel()
        cellFeedTask?.cancel()
        megaBeamStartedAt = nil
        scannerIntegrity = scannerIntegrityCapacity
        essenceFieldRevision += 1
    }

    private func presentCombatFeedback(
        _ feedback: SpecterCombatFeedback,
        milliseconds: Int
    ) {
        combatFeedbackTask?.cancel()
        combatFeedback = feedback
        combatFeedbackStartedAt = Date()
        combatFeedbackEventCounter += 1

        combatFeedbackTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(milliseconds))
            } catch {
                return
            }
            self?.combatFeedback = nil
            self?.combatFeedbackStartedAt = nil
        }
    }

    private func triggerScannerFailsafe() {
        combatFeedbackTask?.cancel()
        scannerRepairTask?.cancel()
        overloadPulseTask?.cancel()
        cellFeedTask?.cancel()
        dischargeCircuitOrchestrator.stop(reason: .playerStopped)
        clearLockOn()
        specterStore.clear()
        lostSoulStore.clear()
        ectoStore.clear()
        encounterStore.endManifestationAsEscaped()
        scannerNotice = nil
        combatFeedback = .scannerFailsafe
        combatFeedbackStartedAt = Date()
        combatFeedbackEventCounter += 1
        scannerFailsafeStartedAt = Date()
        scannerStateStore.setStatus(.scannerFailsafe)

        scannerRepairTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(scannerFailsafeDuration))
            } catch {
                return
            }

            scannerFailsafeStartedAt = nil
            combatFeedback = nil
            combatFeedbackStartedAt = nil
            scannerIntegrity = scannerIntegrityCapacity
            encounterStore.reset()
            beginFreshCalmSearch()
        }
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
        result: WispResearchUploadResult,
        ectoResult: EctoResearchUploadResult = .noSamples
    ) {
        noticeTask?.cancel()
        scannerNotice = .essenceUploaded(samples: samples)

        noticeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await wait(milliseconds: 900) else { return }

            switch result {
            case .noSamples:
                scannerNotice = ectoResult == .noSamples
                    ? .capacitorEmpty
                    : .libraryUpdated

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

            if ectoResult == .documented {
                guard await wait(milliseconds: 1_100) else { return }
                scannerNotice = .ectoCatalogued
            } else if case .contributed = ectoResult {
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
