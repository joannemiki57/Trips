import SwiftUI
import UIKit

enum TripsColor {
    static let bg = Color(light: 0xFFFFFF, dark: 0x000000)
    static let surface = Color(light: 0xFAFAFA, dark: 0x1C1C1E)
    static let textPrimary = Color(light: 0x000000, dark: 0xFFFFFF)
    static let textSecondary = Color(light: 0x737373, dark: 0xA8A8A8)
    static let border = Color(light: 0xDBDBDB, dark: 0x2C2C2E)

    static let accent = Color(hex: 0xFF3040)
    static let success = Color(hex: 0x34C759)
    static let warning = Color(hex: 0xFF9500)
}

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    init(light: UInt32, dark: UInt32) {
        self = Color(uiColor: UIColor(dynamicProvider: { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }))
    }
}
