import AirBatteryShared
import SwiftUI

package enum AirBatteryWidgetDevelopmentFamily: String, Sendable {
    case small
    case medium
    case large
}

/// Package-only entry points for rendering the production widget content
/// outside WidgetKit. This keeps timeline/provider behavior out of UI fixtures.
@MainActor
package enum AirBatteryWidgetDevelopmentSurfaces {
    package static func overview(
        devices: [Device],
        family: AirBatteryWidgetDevelopmentFamily,
        showPercentages: Bool = true,
        showLabels: Bool = true
    ) -> AnyView {
        let sharedFamily: SharedWidgetOverviewFamily = switch family {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }

        return AnyView(
            SharedWidgetOverviewRingsSurfaceContent(
                devices: devices,
                family: sharedFamily,
                showPercentages: showPercentages,
                showLabels: showLabels
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}
