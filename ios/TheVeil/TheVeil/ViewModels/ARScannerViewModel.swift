import Combine
import Foundation

@MainActor
final class ARScannerViewModel: ObservableObject {
    let scannerStateStore: ARScannerStateStore
    let inventoryStore: EssenceInventoryStore
    let visibleEssenceStore: VisibleEssenceStore

    private let essenceFactory: AmbientEssenceFactory

    @MainActor
    init() {
        self.scannerStateStore = ARScannerStateStore()
        self.inventoryStore = EssenceInventoryStore()
        self.visibleEssenceStore = VisibleEssenceStore()
        self.essenceFactory = AmbientEssenceFactory()

        prepareScannerField()
    }

    @MainActor
    init(
        scannerStateStore: ARScannerStateStore,
        inventoryStore: EssenceInventoryStore,
        visibleEssenceStore: VisibleEssenceStore,
        essenceFactory: AmbientEssenceFactory
    ) {
        self.scannerStateStore = scannerStateStore
        self.inventoryStore = inventoryStore
        self.visibleEssenceStore = visibleEssenceStore
        self.essenceFactory = essenceFactory

        prepareScannerField()
    }

    var visibleEssences: [AmbientEssence] {
        visibleEssenceStore.visibleEssences
    }

    func markScannerUnavailable() {
        scannerStateStore.setStatus(.unavailable)
        visibleEssenceStore.replace(with: [])
    }

    func collectEssence(id: AmbientEssence.ID) -> Bool {
        guard let essence = visibleEssenceStore.remove(id: id) else {
            return false
        }

        inventoryStore.collect(essence)

        if visibleEssenceStore.visibleEssenceCount == 0 {
            scannerStateStore.setStatus(.fieldCleared)
        }

        return true
    }

    private func prepareScannerField() {
        visibleEssenceStore.replace(with: essenceFactory.makeInitialField())
        scannerStateStore.setStatus(.scanning)
    }
}
