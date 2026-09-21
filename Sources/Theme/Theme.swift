import SwiftUI

/// Colors per docs/design/uiux/components.md#theme — dark by default,
/// near-black page, one teal accent. Not pure black, not stock blue.
enum Theme {
    static let page = Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255)
    static let surface = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let accent = Color(red: 0x2D / 255, green: 0xB8 / 255, blue: 0xA6 / 255)
    static let positive = Color.green
    static let negative = Color.red
    static let partial = Color.orange
}
