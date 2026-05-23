import SwiftUI

enum TripsFont {
    /// 워드마크 전용 (Trips 로고). 다른 데서 쓰지 말 것.
    static let brand = Font.system(.largeTitle, design: .rounded).weight(.black)

    static let titleXL = Font.system(size: 34, weight: .bold, design: .default)
    static let title = Font.system(size: 22, weight: .bold, design: .default)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let caption = Font.system(size: 14, weight: .regular, design: .default)
    static let captionSmall = Font.system(size: 12, weight: .regular, design: .default)
}
