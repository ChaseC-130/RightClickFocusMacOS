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
        .executableTarget(
            name: "RightClickFocus",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
