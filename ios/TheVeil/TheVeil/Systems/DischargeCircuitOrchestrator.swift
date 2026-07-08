import Foundation

@MainActor
final class DischargeCircuitOrchestrator {
    typealias Delivery = @MainActor (_ amount: Double, _ intensity: Int) -> EncounterResonanceResult
    typealias Completion = @MainActor (_ reason: DischargeCircuitStopReason) -> Void

    private let inventoryStore: EssenceInventoryStore
    private let circuitStore: DischargeCircuitStore
    private var circuitTask: Task<Void, Never>?

    init(
        inventoryStore: EssenceInventoryStore,
        circuitStore: DischargeCircuitStore
    ) {
        self.inventoryStore = inventoryStore
        self.circuitStore = circuitStore
    }

    func start(
        intensity: Int,
        delivery: @escaping Delivery,
        completion: @escaping Completion
    ) {
        stop(reason: .playerStopped)
        circuitStore.start(intensity: intensity)

        circuitTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await runCircuit(delivery: delivery, completion: completion)
        }
    }

    func stop(
        reason: DischargeCircuitStopReason,
        completion: Completion? = nil
    ) {
        guard circuitStore.isActive || circuitTask != nil else {
            return
        }
        circuitTask?.cancel()
        circuitTask = nil
        circuitStore.stop()
        completion?(reason)
    }

    private func runCircuit(
        delivery: @escaping Delivery,
        completion: @escaping Completion
    ) async {
        while circuitStore.isActive {
            var didConsumePacket = inventoryStore.consumeDischargePacket()
            if !didConsumePacket {
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
                didConsumePacket = inventoryStore.consumeDischargePacket()
            }

            guard didConsumePacket else {
                finish(reason: .capacitorEmpty, completion: completion)
                return
            }

            circuitStore.beginPacket()
            let duration = circuitStore.state.packetDuration
            let intensity = circuitStore.state.intensity
            var elapsed: TimeInterval = 0
            var deliveredInPacket: Double = 0
            var previous = ContinuousClock.now

            while elapsed < duration, circuitStore.isActive {
                do {
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    return
                }

                let now = ContinuousClock.now
                let delta = min(previous.duration(to: now).timeInterval, duration - elapsed)
                previous = now
                elapsed += delta

                let deliveredAmount = min(
                    max(delta / duration, 0),
                    1 - deliveredInPacket
                )
                deliveredInPacket += deliveredAmount
                let result = delivery(deliveredAmount, intensity)
                circuitStore.updatePacketProgress(elapsed / duration)

                if result == .thresholdReached {
                    finish(reason: .encounterThresholdReached, completion: completion)
                    return
                }
            }

            guard circuitStore.isActive else {
                return
            }

            let remainingAmount = max(0, 1 - deliveredInPacket)
            if remainingAmount > 0.000_001 {
                let result = delivery(remainingAmount, intensity)
                circuitStore.updatePacketProgress(1)

                if result == .thresholdReached {
                    finish(reason: .encounterThresholdReached, completion: completion)
                    return
                }
            }
        }
    }

    private func finish(
        reason: DischargeCircuitStopReason,
        completion: Completion
    ) {
        circuitTask = nil
        circuitStore.stop()
        completion(reason)
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
