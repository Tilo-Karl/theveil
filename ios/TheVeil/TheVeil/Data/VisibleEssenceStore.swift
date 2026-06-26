import Combine
import Foundation

@MainActor
final class VisibleEssenceStore: ObservableObject {
    @Published private(set) var visibleEssences: [AmbientEssence] = []

    var visibleEssenceCount: Int {
        visibleEssences.count
    }

    private var essencesByID: [AmbientEssence.ID: AmbientEssence] = [:]

    func replace(with essences: [AmbientEssence]) {
        visibleEssences = essences
        essencesByID = Dictionary(uniqueKeysWithValues: essences.map { ($0.id, $0) })
    }

    func remove(id: AmbientEssence.ID) -> AmbientEssence? {
        let essence = essencesByID.removeValue(forKey: id)
        visibleEssences.removeAll { $0.id == id }
        return essence
    }
}
