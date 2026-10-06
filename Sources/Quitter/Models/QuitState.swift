import Foundation

enum QuitState: Equatable, Sendable {
    case idle
    /// `terminate()` sent at this time; waiting for the app to exit.
    case requested(at: Date)
    /// Timeout passed, or `terminate()` returned false. Row offers Force Quit.
    case stuck
    case terminated

    var isPending: Bool {
        switch self {
        case .requested, .stuck: true
        case .idle, .terminated: false
        }
    }
}
