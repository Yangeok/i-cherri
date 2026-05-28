// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ICherriCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ICherriCore", targets: ["ICherriCore"])
    ],
    dependencies: [
        .package(path: "../ICherriProtocol")
    ],
    targets: [
        .target(
            name: "ICherriCore",
            dependencies: ["ICherriProtocol"],
            path: "Sources/ICherriCore"
        ),
        .testTarget(
            name: "ICherriCoreTests",
            dependencies: ["ICherriCore"],
            path: "Tests/ICherriCoreTests"
        )
    ]
)
