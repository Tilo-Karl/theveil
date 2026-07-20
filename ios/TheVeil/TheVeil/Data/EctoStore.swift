import Combine

@MainActor
final class EctoStore: ObservableObject {
    @Published private(set) var activeEcto: Ecto?
    @Published private(set) var ectoplasmicDamage: Double = 0

    func spawn(_ ecto: Ecto) {
        activeEcto = ecto
        ectoplasmicDamage = 0
    }

    func clear() {
        activeEcto = nil
        ectoplasmicDamage = 0
    }

    func remove(id: Ecto.ID) -> Ecto? {
        guard activeEcto?.id == id else {
            return nil
        }

        let removedEcto = activeEcto
        activeEcto = nil
        ectoplasmicDamage = 0
        return removedEcto
    }

    func applyScannerZap(id: Ecto.ID, damage: Double? = nil) -> EctoResonanceResult {
        let zapDamage = damage ?? Ecto.scannerZapDamage
        guard let activeEcto, activeEcto.id == id, zapDamage > 0 else {
            return .noEffect
        }

        ectoplasmicDamage = min(
            ectoplasmicDamage + zapDamage,
            Ecto.ectoplasmicIntegrity
        )

        guard ectoplasmicDamage >= Ecto.ectoplasmicIntegrity else {
            return .progressed(
                current: ectoplasmicDamage,
                required: Ecto.ectoplasmicIntegrity
            )
        }

        self.activeEcto = nil
        ectoplasmicDamage = 0
        return .thresholdReached(activeEcto)
    }
}
