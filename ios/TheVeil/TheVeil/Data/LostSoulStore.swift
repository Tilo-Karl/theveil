import Combine
import Foundation

@MainActor
final class LostSoulStore: ObservableObject {
    @Published private(set) var lostSoul: LostSoul?

    func manifest(_ lostSoul: LostSoul) {
        self.lostSoul = lostSoul
    }

    func clear() {
        lostSoul = nil
    }
}
