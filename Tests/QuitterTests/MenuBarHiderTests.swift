import CoreGraphics
import Testing
@testable import Quitter

struct MenuBarHiderTests {
    @Test func hiddenLengthReachesTheScreensLeftEdge() {
        // Divider ending at x = 3108 on a display starting at x = 2560.
        #expect(MenuBarHider.hiddenLength(dividerMaxX: 3108, screenMinX: 2560) == 556)
        // Never shorter than the visible divider.
        #expect(MenuBarHider.hiddenLength(dividerMaxX: 2560, screenMinX: 2560) == MenuBarHider.dividerLength)
    }

    @Test func framesMoveBetweenDisplaysByRightAndTopEdges() {
        let main = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        let portrait = CGRect(x: 2560, y: -648, width: 1440, height: 2560)
        // An icon 896 pt left of the main display's right edge keeps that offset on the other one.
        let onMain = CGRect(x: 1664, y: 3, width: 24, height: 24)
        let onPortrait = MenuBarHider.translate(onMain, from: main, to: portrait)
        #expect(onPortrait == CGRect(x: 3104, y: -645, width: 24, height: 24))
    }
}
