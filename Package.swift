// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AirBattery",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "AirBatteryKit",
            targets: ["AirBatteryKit"]
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
            name: "AirBatteryKit",
            dependencies: [
                .product(name: "MultipeerKit", package: "MultipeerKit"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "AirBattery",
            exclude: [
                "AirBattery.entitlements",
                "Base.lproj",
                "Info.plist",
                "Preview Content",
                "libimobiledevice",
                "Supports",
                "UI/Widget",
                "en.lproj",
            ]
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
