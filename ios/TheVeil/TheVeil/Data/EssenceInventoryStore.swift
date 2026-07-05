import Combine
import Foundation

@MainActor
final class EssenceInventoryStore: ObservableObject {
    @Published private(set) var capacitorEssenceCount = 0
    @Published private(set) var isIntegratedCellUnlocked: Bool
    @Published private(set) var containmentCellEssenceCount: Int

    let equipment: VeilEquipmentConfiguration

    private let defaults: UserDefaults
    private let integratedCellUnlockedKey = "inventory.integratedContainmentCell.unlocked"
    private let integratedCellChargeKey = "inventory.integratedContainmentCell.charge"
    private let integratedCellMigrationKey = "inventory.integratedContainmentCell.migrated"
    private let legacyContainmentCellCountKey = "inventory.containmentCells"

    init(
        defaults: UserDefaults = .standard,
        equipment: VeilEquipmentConfiguration = .fieldScanner
    ) {
        self.defaults = defaults
        self.equipment = equipment

        if
            !defaults.bool(forKey: integratedCellMigrationKey),
            defaults.integer(forKey: legacyContainmentCellCountKey) > 0
        {
            self.isIntegratedCellUnlocked = true
            self.containmentCellEssenceCount = equipment.containmentCellCapacity
            defaults.set(true, forKey: integratedCellUnlockedKey)
            defaults.set(
                equipment.containmentCellCapacity,
                forKey: integratedCellChargeKey
            )
        } else {
            self.isIntegratedCellUnlocked = defaults.bool(forKey: integratedCellUnlockedKey)
            self.containmentCellEssenceCount = min(
                max(0, defaults.integer(forKey: integratedCellChargeKey)),
                equipment.containmentCellCapacity
            )
        }

        defaults.set(true, forKey: integratedCellMigrationKey)
    }

    func canCollect(_ essence: AmbientEssence) -> Bool {
        essence.value > 0
            && capacitorEssenceCount + essence.value <= equipment.capacitorCapacity
    }

    func collect(_ essence: AmbientEssence) -> Bool {
        guard canCollect(essence) else {
            return false
        }

        capacitorEssenceCount += essence.value
        return true
    }

    func uploadCapacitorEssence() -> Int {
        let uploadedEssence = capacitorEssenceCount
        capacitorEssenceCount = 0
        return uploadedEssence
    }

    func consumeDischargePacket() -> Bool {
        guard capacitorEssenceCount > 0 else {
            return false
        }
        capacitorEssenceCount -= 1
        return true
    }

    func unlockIntegratedCell() {
        guard !isIntegratedCellUnlocked else {
            return
        }

        isIntegratedCellUnlocked = true
        defaults.set(true, forKey: integratedCellUnlockedKey)
    }

    func transferCapacitorEssenceToCell(
        essenceIsIdentified: Bool
    ) -> ContainmentTransferResult {
        guard capacitorEssenceCount > 0 else {
            return .noEssence
        }
        guard essenceIsIdentified else {
            return .unidentifiedEssence
        }
        guard isIntegratedCellUnlocked else {
            return .cellLocked
        }

        let availableCellCapacity = equipment.containmentCellCapacity
            - containmentCellEssenceCount
        guard availableCellCapacity > 0 else {
            return .cellFull
        }

        let transferredEssence = min(capacitorEssenceCount, availableCellCapacity)
        capacitorEssenceCount -= transferredEssence
        containmentCellEssenceCount += transferredEssence
        defaults.set(containmentCellEssenceCount, forKey: integratedCellChargeKey)
        return .transferred(essence: transferredEssence)
    }

    func activateContainmentCell() -> ContainmentCellActivationResult {
        guard isIntegratedCellUnlocked else {
            return .cellLocked
        }
        guard containmentCellEssenceCount > 0 else {
            return .cellEmpty
        }

        if capacitorEssenceCount < equipment.capacitorCapacity {
            let availableCapacity = equipment.capacitorCapacity - capacitorEssenceCount
            let transferredEssence = min(availableCapacity, containmentCellEssenceCount)
            capacitorEssenceCount += transferredEssence
            containmentCellEssenceCount -= transferredEssence
            persistContainmentCellCharge()
            return .capacitorRefilled(
                transferredEssence: transferredEssence,
                capacitorCharge: capacitorEssenceCount,
                cellCharge: containmentCellEssenceCount
            )
        }

        let injectedEssence = containmentCellEssenceCount
        capacitorEssenceCount += injectedEssence
        containmentCellEssenceCount = 0
        persistContainmentCellCharge()
        return .capacitorOverloaded(
            peakCharge: capacitorEssenceCount,
            capacitorCapacity: equipment.capacitorCapacity,
            injectedEssence: injectedEssence
        )
    }

    private func persistContainmentCellCharge() {
        defaults.set(containmentCellEssenceCount, forKey: integratedCellChargeKey)
    }
}
