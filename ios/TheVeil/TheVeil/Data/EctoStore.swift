import Combine

@MainActor
final class EctoStore: ObservableObject {
    @Published private(set) var activeEcto: Ecto?

    func spawn(_ ecto: Ecto) {
        activeEcto = ecto
    }

    func clear() {
        activeEcto = nil
    }

    func remove(id: Ecto.ID) -> Ecto? {
        guard activeEcto?.id == id else {
            return nil
        }

        let removedEcto = activeEcto
        activeEcto = nil
        return removedEcto
    }
}
