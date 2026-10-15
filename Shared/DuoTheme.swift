import SwiftUI

enum DuoTheme {
    static let background = Color(red: 0.09, green: 0.075, blue: 0.063)
    static let ink = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let muted = Color(red: 0.72, green: 0.66, blue: 0.58)
    static let paper = Color(red: 0.96, green: 0.92, blue: 0.86)
    static let paperInk = Color(red: 0.16, green: 0.12, blue: 0.09)
    static let shutter = Color(red: 0.84, green: 0.20, blue: 0.16)
    static let olive = Color(red: 0.49, green: 0.55, blue: 0.34)
    static let line = Color.white.opacity(0.08)

    static let serifTitle = Font.system(.title2, design: .serif).weight(.semibold)
    static let serifLarge = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let roundedBody = Font.system(.body, design: .rounded)
    static let roundedCaption = Font.system(.caption, design: .rounded)
}
