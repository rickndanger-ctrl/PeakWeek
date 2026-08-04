// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PeakWeek",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        // Shared engine + models: everything the iOS client app and the Mac
        // coach app both need. Pure Foundation — no UI frameworks.
        .library(name: "PeakWeekCore", targets: ["PeakWeekCore"]),
    ],
    targets: [
        .target(
            name: "PeakWeekCore",
            path: "Sources/PeakWeekCore"
        ),
        .executableTarget(
            name: "PeakWeek",
            dependencies: ["PeakWeekCore"],
            path: "Sources/PeakWeek"
        ),
        .testTarget(
            name: "PeakWeekTests",
            dependencies: ["PeakWeek"],
            path: "Tests/PeakWeekTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
