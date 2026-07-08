import Foundation

enum SpecterCombatEvent: Equatable {
    case attackTelegraph
    case boltFired
    case boltHit
    case boltDodged
}

enum SpecterCombatFeedback: Equatable {
    case incoming
    case hit
    case dodged
    case scannerFailsafe
}
