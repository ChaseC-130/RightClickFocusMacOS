// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RightClickFocus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RightClickFocus", targets: ["RightClickFocus"])
    ],
    targets: [
        .target(name: "CarbonActivationShim"),
        .executableTarget(
            name: "RightClickFocus",
            dependencies: ["CarbonActivationShim"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security")
            ]
        )
    ]
)
