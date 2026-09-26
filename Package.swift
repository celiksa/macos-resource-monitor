// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Vitals",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Vitals", targets: ["Vitals"])
    ],
    targets: [
        .executableTarget(
            name: "Vitals",
            path: "Sources/Vitals",
            swiftSettings: [
                // Use Swift 5 language mode to avoid strict-concurrency friction with
                // the many C/IOKit interop points; the Swift 6 compiler is still used.
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .testTarget(name: "VitalsTests", dependencies: ["Vitals"], swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
