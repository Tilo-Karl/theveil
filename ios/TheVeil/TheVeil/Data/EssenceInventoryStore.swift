import Combine
import Foundation

@MainActor
final class EssenceInventoryStore: ObservableObject {
    @Published private(set) var capacitorEssenceCount: Int
    @Published private(set) var isIntegratedCellUnlocked: Bool
    @Published private(set) var containmentCellEssenceCount: Int

    let equipment: VeilEquipmentConfiguration

    private let defaults: UserDefaults
    private let capacitorChargeKey = "inventory.veilCapacitor.charge"
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
        self.capacitorEssenceCount = min(
            max(0, defaults.integer(forKey: capacitorChargeKey)),
            equipment.capacitorCapacity
        )

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

        capacitorEssenceCount = equipment.capacitorCapacity
        isIntegratedCellUnlocked = true
        containmentCellEssenceCount = equipment.containmentCellCapacity
        defaults.set(true, forKey: integratedCellUnlockedKey)
        persistCapacitorCharge()
        persistContainmentCellCharge()
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
        persistCapacitorCharge()
        return true
    }

    func uploadCapacitorEssence() -> Int {
        let uploadedEssence = capacitorEssenceCount
        capacitorEssenceCount = 0
        persistCapacitorCharge()
        return uploadedEssence
    }

    func consumeDischargePacket() -> Bool {
        guard capacitorEssenceCount > 0 else {
            return false
        }
        capacitorEssenceCount -= 1
        persistCapacitorCharge()
        return true
    }

    func consumeCapacitorEssence(_ amount: Int) -> Int {
        let consumedEssence = min(max(amount, 0), capacitorEssenceCount)
        guard consumedEssence > 0 else {
            return 0
        }

        capacitorEssenceCount -= consumedEssence
        persistCapacitorCharge()
        return consumedEssence
    }

    func transferCellEssenceToCapacitor() -> Bool {
        guard
            isIntegratedCellUnlocked,
            containmentCellEssenceCount > 0,
            capacitorEssenceCount < equipment.capacitorCapacity
        else {
            return false
        }

        capacitorEssenceCount += 1
        containmentCellEssenceCount -= 1
        persistCapacitorCharge()
        persistContainmentCellCharge()
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
        persistCapacitorCharge()
        defaults.set(containmentCellEssenceCount, forKey: integratedCellChargeKey)
        return .transferred(essence: transferredEssence)
    }

    private func persistContainmentCellCharge() {
        defaults.set(containmentCellEssenceCount, forKey: integratedCellChargeKey)
    }

    private func persistCapacitorCharge() {
        defaults.set(capacitorEssenceCount, forKey: capacitorChargeKey)
    }
}
