// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ICherriPreviewSupport",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ICherriPreviewSupport", targets: ["ICherriPreviewSupport"])
    ],
    dependencies: [
        .package(path: "../ICherriProtocol"),
        .package(path: "../ICherriCore"),
        .package(path: "../ICherriDesignSystem")
    ],
    targets: [
        .target(
            name: "ICherriPreviewSupport",
            dependencies: ["ICherriProtocol", "ICherriCore", "ICherriDesignSystem"],
            path: "Sources/ICherriPreviewSupport"
        )
    ]
)
