#if SWIFT_PACKAGE
import SwiftUI

/// SwiftPM processes the asset catalog but does not synthesize the typed color
/// symbols that Xcode creates for application targets. Keep this compatibility
/// surface package-only so Xcode builds continue to use their generated symbols.
extension Color {
    static let blackWhite = Color("black_white", bundle: .module)
    static let blue1 = Color("blue1", bundle: .module)
    static let blue2 = Color("blue2", bundle: .module)
    static let darkMyGreen = Color("dark_my_green", bundle: .module)
    static let darkMyRed = Color("dark_my_red", bundle: .module)
    static let darkMyYellow = Color("dark_my_yellow", bundle: .module)
    static let myBlue = Color("my_blue", bundle: .module)
    static let myGreen = Color("my_green", bundle: .module)
    static let myGreen2 = Color("my_green2", bundle: .module)
    static let myRed = Color("my_red", bundle: .module)
    static let myRed2 = Color("my_red2", bundle: .module)
    static let myYellow = Color("my_yellow", bundle: .module)
}
#endif
