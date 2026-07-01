import Combine
import Foundation

@MainActor
final class EssenceInventoryStore: ObservableObject {
    @Published private(set) var capacitorEssenceCount = 0
    @Published private(set) var containmentCellCount: Int

    private let defaults: UserDefaults
    private let containmentCellCountKey = "inventory.containmentCells"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.containmentCellCount = max(0, defaults.integer(forKey: containmentCellCountKey))
    }

    func collect(_ essence: AmbientEssence) {
        capacitorEssenceCount += essence.value
    }

    func spend(_ amount: Int) -> Bool {
        guard amount > 0, capacitorEssenceCount >= amount else {
            return false
        }

        capacitorEssenceCount -= amount
        return true
    }

    func craftContainmentCell(cost: Int) -> Bool {
        guard spend(cost) else {
            return false
        }

        containmentCellCount += 1
        defaults.set(containmentCellCount, forKey: containmentCellCountKey)
        return true
    }
}
