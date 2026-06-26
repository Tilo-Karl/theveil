import Combine
import Foundation

@MainActor
final class EssenceInventoryStore: ObservableObject {
    @Published private(set) var ambientEssenceCount = 0

    func collect(_ essence: AmbientEssence) {
        ambientEssenceCount += essence.value
    }
}
