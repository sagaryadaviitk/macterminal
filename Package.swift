// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacTerminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacTerminal", targets: ["MacTerminal"]),
        .library(name: "MacTerminalCore", targets: ["MacTerminalCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sagaryadaviitk/SwiftTerm.git", revision: "77b7b23ac3aaa0c8a6ead9866e085732d50e4118")
    ],
    targets: [
        .target(
            name: "MacTerminalCore"
        ),
        .executableTarget(
            name: "MacTerminal",
            dependencies: [
                "MacTerminalCore",
                "SwiftTerm"
            ],
            exclude: ["Info.plist"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "MacTerminalCoreTests",
            dependencies: ["MacTerminalCore"]
        ),
        .testTarget(
            name: "MacTerminalInteractionTests",
            dependencies: ["MacTerminal", "SwiftTerm"]
        )
    ]
)
