import SwiftUI

enum AppTheme {
    enum ColorToken {
        static let cardStroke = Color.white.opacity(0.22)
        static let cardFill = Color.white.opacity(0.08)
    }

    enum Radius {
        static let large: CGFloat = 18
        static let medium: CGFloat = 14
    }

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.14)
        static let normal = Animation.easeOut(duration: 0.2)
    }
}
