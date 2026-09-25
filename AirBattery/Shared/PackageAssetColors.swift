#if SWIFT_PACKAGE
import SwiftUI

/// SwiftPM processes the asset catalog but does not synthesize the typed color
/// symbols that Xcode creates for application targets. Keep this compatibility
/// surface package-only so Xcode builds continue to use their generated symbols.
extension Color {
    static let blackWhite = Color("black_white", bundle: .module)
    static let myGreen = Color("my_green", bundle: .module)
    static let myYellow = Color("my_yellow", bundle: .module)
}
#endif
