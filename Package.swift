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
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.13.0")
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
        )
    ]
)
