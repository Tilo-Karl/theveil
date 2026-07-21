import Combine
import Foundation

@MainActor
final class EssenceInventoryStore: ObservableObject {
    @Published private(set) var capacitorEssenceCount: Int
    @Published private(set) var capacitorEctoSampleCount: Int
    @Published private(set) var isIntegratedCellUnlocked: Bool
    @Published private(set) var containmentCellEssenceCount: Int

    let equipment: VeilEquipmentConfiguration

    private let defaults: UserDefaults
    private let capacitorChargeKey = "inventory.veilCapacitor.charge"
    private let capacitorEctoSamplesKey = "inventory.veilCapacitor.ectoSamples"
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
        let storedCapacitorEssenceCount = min(
            max(0, defaults.integer(forKey: capacitorChargeKey)),
            equipment.capacitorCapacity
        )
        self.capacitorEssenceCount = storedCapacitorEssenceCount
        self.capacitorEctoSampleCount = min(
            max(0, defaults.integer(forKey: capacitorEctoSamplesKey)),
            storedCapacitorEssenceCount
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

        capacitorEssenceCount = 0
        capacitorEctoSampleCount = 0
        isIntegratedCellUnlocked = true
        containmentCellEssenceCount = equipment.containmentCellCapacity
        defaults.set(true, forKey: integratedCellUnlockedKey)
        persistCapacitorCharge()
        persistCapacitorEctoSamples()
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

    func collectEctoSample(value: Int) -> Bool {
        guard value > 0, capacitorEssenceCount + value <= equipment.capacitorCapacity else {
            return false
        }

        capacitorEssenceCount += value
        capacitorEctoSampleCount += value
        persistCapacitorCharge()
        persistCapacitorEctoSamples()
        return true
    }

    func uploadCapacitorContents() -> UploadedEssenceBatch {
        let uploadedEssence = capacitorEssenceCount
        let uploadedEctoSamples = min(capacitorEctoSampleCount, uploadedEssence)
        capacitorEssenceCount = 0
        capacitorEctoSampleCount = 0
        persistCapacitorCharge()
        persistCapacitorEctoSamples()
        return UploadedEssenceBatch(
            totalSamples: uploadedEssence,
            ectoSamples: uploadedEctoSamples
        )
    }

    func uploadCapacitorEssence() -> Int {
        uploadCapacitorContents().totalSamples
    }

    func consumeDischargePacket() -> Bool {
        guard capacitorEssenceCount > 0 else {
            return false
        }
        capacitorEssenceCount -= 1
        if capacitorEctoSampleCount > 0 {
            capacitorEctoSampleCount -= 1
        }
        persistCapacitorCharge()
        persistCapacitorEctoSamples()
        return true
    }

    func consumeCapacitorEssence(_ amount: Int) -> Int {
        let consumedEssence = min(max(amount, 0), capacitorEssenceCount)
        guard consumedEssence > 0 else {
            return 0
        }

        capacitorEssenceCount -= consumedEssence
        capacitorEctoSampleCount = max(capacitorEctoSampleCount - consumedEssence, 0)
        persistCapacitorCharge()
        persistCapacitorEctoSamples()
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
        capacitorEctoSampleCount = max(capacitorEctoSampleCount - transferredEssence, 0)
        containmentCellEssenceCount += transferredEssence
        persistCapacitorCharge()
        persistCapacitorEctoSamples()
        defaults.set(containmentCellEssenceCount, forKey: integratedCellChargeKey)
        return .transferred(essence: transferredEssence)
    }

    private func persistContainmentCellCharge() {
        defaults.set(containmentCellEssenceCount, forKey: integratedCellChargeKey)
    }

    private func persistCapacitorCharge() {
        defaults.set(capacitorEssenceCount, forKey: capacitorChargeKey)
    }

    private func persistCapacitorEctoSamples() {
        defaults.set(capacitorEctoSampleCount, forKey: capacitorEctoSamplesKey)
    }
}
