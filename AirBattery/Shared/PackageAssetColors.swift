#if SWIFT_PACKAGE
import SwiftUI

/// AirBatteryKit deliberately leaves the application asset catalog in the
/// packaging layer. Command-line SwiftPM builds therefore need source-level
/// names for colors that Xcode normally synthesizes from that catalog. At
/// runtime these names resolve from the host app bundle.
extension Color {
    static let blackWhite = Color("black_white")
    static let blue1 = Color("blue1")
    static let blue2 = Color("blue2")
    static let darkMyGreen = Color("dark_my_green")
    static let darkMyRed = Color("dark_my_red")
    static let darkMyYellow = Color("dark_my_yellow")
    static let myBlue = Color("my_blue")
    static let myGreen = Color("my_green")
    static let myGreen2 = Color("my_green2")
    static let myRed = Color("my_red")
    static let myRed2 = Color("my_red2")
    static let myYellow = Color("my_yellow")
}
#endif
