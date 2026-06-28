import Combine
import Foundation

@MainActor
final class ARScannerViewModel: ObservableObject {
    let scannerStateStore: ARScannerStateStore
    let inventoryStore: EssenceInventoryStore
    let visibleEssenceStore: VisibleEssenceStore
    let lostSoulStore: LostSoulStore

    private let essenceFactory: AmbientEssenceFactory

    @Published private(set) var lockOnProgress: Double = 0
    @Published private(set) var lockOnTargetID: UUID?

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

        if visibleEssenceStore.visibleEssenceCount == 0 {
            lostSoulStore.manifest(LostSoul(id: UUID()))
            scannerStateStore.setStatus(.lostSoulManifested)
        }

        return true
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
}
