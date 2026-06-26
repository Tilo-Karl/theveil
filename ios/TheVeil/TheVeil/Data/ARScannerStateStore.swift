import Combine
import Foundation

@MainActor
final class ARScannerStateStore: ObservableObject {
    @Published private(set) var status: ARScannerStatus = .initializing

    func setStatus(_ status: ARScannerStatus) {
        self.status = status
    }
}
