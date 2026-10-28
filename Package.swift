// swift-tools-version: 6.0

import Foundation
import PackageDescription

// Command Line Tools ship Swift Testing outside the default search paths.
// Xcode finds its own copy; adding the CLT framework there mismatches the
// @Test macro and library, so only add these flags for a CLT toolchain.
let commandLineToolsDirectory = "/Library/Developer/CommandLineTools"
let activeDeveloperDirectory = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
    ?? (try? FileManager.default.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link"))
    ?? ""
let usesCommandLineTools = activeDeveloperDirectory.hasPrefix(commandLineToolsDirectory)
let testingFrameworks = "\(commandLineToolsDirectory)/Library/Developer/Frameworks"
let testingSwiftSettings: [SwiftSetting] = usesCommandLineTools
    ? [.unsafeFlags(["-F", testingFrameworks])]
    : []
let testingLinkerSettings: [LinkerSetting] = usesCommandLineTools
    ? [
        .unsafeFlags([
            "-F", testingFrameworks,
            "-Xlinker", "-rpath", "-Xlinker", testingFrameworks,
            "-Xlinker", "-rpath", "-Xlinker", "\(commandLineToolsDirectory)/Library/Developer/usr/lib",
        ]),
        .linkedFramework("Testing"),
    ]
    : []

let package = Package(
    name: "joy-con-codex-controller-community",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "JoyConCodexCore",
            targets: ["JoyConCodexCore"]
        ),
        .executable(
            name: "JoyConUnifiedController",
            targets: ["JoyConCodexController"]
        ),
    ],
    targets: [
        .target(
            name: "JoyConCodexCore"
        ),
        .executableTarget(
            name: "JoyConCodexController",
            dependencies: ["JoyConCodexCore"],
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreHaptics"),
                .linkedFramework("GameController"),
                .linkedFramework("IOKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .executableTarget(
            name: "JoyConInputLogger",
            path: "Tools/JoyConInputLogger",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .testTarget(
            name: "JoyConCodexCoreTests",
            dependencies: ["JoyConCodexCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
