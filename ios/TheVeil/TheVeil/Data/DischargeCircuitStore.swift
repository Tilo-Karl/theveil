import Combine
import Foundation

@MainActor
final class DischargeCircuitStore: ObservableObject {
    @Published private(set) var state = DischargeCircuitState()

    var isActive: Bool {
        state.isActive
    }

    func start(intensity: Int) {
        state.isActive = true
        state.intensity = max(intensity, 1)
        state.packetProgress = 0
        state.packetDuration = 2 / Double(state.intensity)
    }

    func beginPacket() {
        state.packetProgress = 0
    }

    func updatePacketProgress(_ progress: Double) {
        state.packetProgress = min(max(progress, 0), 1)
    }

    func stop() {
        state.isActive = false
        state.packetProgress = 0
    }
}
