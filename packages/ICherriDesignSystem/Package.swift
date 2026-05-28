// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ICherriDesignSystem",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ICherriDesignSystem", targets: ["ICherriDesignSystem"])
    ],
    dependencies: [
        .package(path: "../ICherriProtocol")
    ],
    targets: [
        .target(
            name: "ICherriDesignSystem",
            dependencies: ["ICherriProtocol"],
            path: "Sources/ICherriDesignSystem"
        )
    ]
)
