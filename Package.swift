// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AirBattery",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "AirBatteryShared",
            targets: ["AirBatteryShared"]
        ),
        .library(
            name: "AirBatteryKit",
            targets: ["AirBatteryKit"]
        ),
        .library(
            name: "AirBatteryWidgetKit",
            targets: ["AirBatteryWidgetKit"]
        ),
        .executable(
            name: "airbattery",
            targets: ["abt"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/insidegui/MultipeerKit.git",
            from: "0.4.0"
        ),
        .package(
            url: "https://github.com/sparkle-project/Sparkle.git",
            from: "2.10.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.8.2"
        ),
    ],
    targets: [
        .target(
            name: "AirBatteryShared",
            path: "AirBattery",
            sources: [
                "Domain",
                "Preferences/AppPreferences.swift",
                "Preferences/UserDefaultsSupport.swift",
                "Services/BatteryHistorySharedReader.swift",
                "Services/BatterySnapshotStore.swift",
                "Services/System/FileSystem.swift",
                "Shared/Extensions.swift",
                "UI/Components/BatteryColors.swift",
                "UI/Components/DeviceIconCatalog.swift",
                "UI/Components/WidgetSurfaces.swift",
            ]
        ),
        .target(
            name: "AirBatteryKit",
            dependencies: [
                "AirBatteryShared",
                .product(name: "MultipeerKit", package: "MultipeerKit"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "AirBattery",
            exclude: [
                "AirBattery.entitlements",
                "Assets.xcassets",
                "Base.lproj",
                "Domain",
                "Info.plist",
                "Preferences/AppPreferences.swift",
                "Preferences/UserDefaultsSupport.swift",
                "Preview Content",
                "Services/BatteryHistorySharedReader.swift",
                "Services/BatterySnapshotStore.swift",
                "Services/System/FileSystem.swift",
                "Shared/Extensions.swift",
                "UI/Components/BatteryColors.swift",
                "UI/Components/DeviceIconCatalog.swift",
                "UI/Components/WidgetSurfaces.swift",
                "UI/Widget",
                "libimobiledevice",
                "Supports",
                "en.lproj",
            ]
        ),
        .target(
            name: "AirBatteryWidgetKit",
            dependencies: ["AirBatteryShared"],
            path: "AirBattery/UI/Widget"
        ),
        .executableTarget(
            name: "abt",
            dependencies: [
                "AirBatteryKit",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
            ],
            path: "abt",
            exclude: ["abt.entitlements"]
        ),
        .testTarget(
            name: "AirBatteryTests",
            dependencies: ["AirBatteryKit"],
            path: "AirBatteryTests"
        ),
    ]
)
