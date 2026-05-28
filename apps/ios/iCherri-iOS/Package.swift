// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCherri-iOS",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "iCherri-iOS", targets: ["iCherri-iOS"])
    ],
    dependencies: [
        .package(path: "../../../packages/ICherriProtocol"),
        .package(path: "../../../packages/ICherriCore"),
        .package(path: "../../../packages/ICherriDesignSystem")
    ],
    targets: [
        .target(
            name: "iCherri-iOS",
            dependencies: ["ICherriProtocol", "ICherriCore", "ICherriDesignSystem"],
            path: ".",
            sources: ["Platform", "Features"]
        )
    ]
)
