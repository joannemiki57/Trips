import SwiftUI

/// A5 LOCKED — 전환 ≤ 250ms easeOut, 인터랙션은 스프링·하프틱
enum TripsMotion {
    static let transitionDuration: Double = 0.25

    static let transition: Animation = .easeOut(duration: transitionDuration)
    static let snap: Animation = .spring(response: 0.32, dampingFraction: 0.78, blendDuration: 0)
    static let favoriteCrossfade: Animation = .easeOut(duration: 0.18)
}
