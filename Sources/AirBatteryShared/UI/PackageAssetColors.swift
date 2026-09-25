#if SWIFT_PACKAGE
import SwiftUI

/// Shared package code leaves the application asset catalog in the packaging
/// layer. Command-line SwiftPM builds therefore need source-level names for
/// colors that Xcode normally synthesizes from that catalog. At runtime these
/// names resolve from the host app or widget bundle.
extension Color {
    package static let blackWhite = Color("black_white")
    package static let blue1 = Color("blue1")
    package static let blue2 = Color("blue2")
    package static let darkMyGreen = Color("dark_my_green")
    package static let darkMyRed = Color("dark_my_red")
    package static let darkMyYellow = Color("dark_my_yellow")
    package static let myBlue = Color("my_blue")
    package static let myGreen = Color("my_green")
    package static let myGreen2 = Color("my_green2")
    package static let myRed = Color("my_red")
    package static let myRed2 = Color("my_red2")
    package static let myYellow = Color("my_yellow")
}
#endif
