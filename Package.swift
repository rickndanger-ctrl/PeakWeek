// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PeakWeek",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PeakWeek",
            path: "Sources/PeakWeek"
        )
    ]
)
