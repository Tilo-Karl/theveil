import Combine
import Foundation
import simd

@MainActor
final class SpecterStore: ObservableObject {
    @Published private(set) var activeSpecter: Specter?

    var hasActiveSpecter: Bool {
        activeSpecter != nil
    }

    func manifest(_ specter: Specter) {
        activeSpecter = specter
    }

    func manifest() {
        activeSpecter = Specter()
    }

    func manifestMinorSpecter(position: SIMD3<Float> = SIMD3<Float>(0, 0, -1)) {
        activeSpecter = Specter(
            position: position,
            phase: Float.random(in: 0...1)
        )
    }

    func clear() {
        activeSpecter = nil
    }
}
