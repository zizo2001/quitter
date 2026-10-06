import AppKit

/// Sendable snapshot of a keyDown event, so key handling can hop onto the main actor
/// without carrying the (non-Sendable) NSEvent.
struct KeyPress: Sendable {
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let space: UInt16 = 49
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125

    let code: UInt16
    let characters: String
    let command: Bool
    let shift: Bool
    let option: Bool
    let control: Bool

    init(_ event: NSEvent) {
        code = event.keyCode
        characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        command = flags.contains(.command)
        shift = flags.contains(.shift)
        option = flags.contains(.option)
        control = flags.contains(.control)
    }
}
