// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LawSenseCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "LawSenseCore", targets: ["LawSenseCore"])],
    targets: [
        .target(name: "LawSenseCore", path: "LawSense/Domain"),
        .testTarget(name: "LawSenseCoreTests", dependencies: ["LawSenseCore"], path: "CoreTests")
    ]
)
