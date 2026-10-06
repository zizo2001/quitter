import SwiftUI

/// Design tokens from PLAN §7. Every size in the UI comes from here.
enum Tokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Radius {
        static let row: CGFloat = 10
        static let field: CGFloat = 14
        static let panel: CGFloat = 22
    }

    enum Size {
        static let icon: CGFloat = 28
        static let row: CGFloat = 44
        static let panelWidth: CGFloat = 340
        static let panelMaxHeight: CGFloat = 540
        static let header: CGFloat = 36
        static let search: CGFloat = 32
        static let chips: CGFloat = 32
        static let footer: CGFloat = 48
        static let listInset: CGFloat = 8
    }

    enum Motion {
        static let panelFade: TimeInterval = 0.15
        static let panelSlide: CGFloat = 4
        static let rowExit: TimeInterval = 0.3
    }
}
