// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCherri-Mac",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "iCherri-Mac", targets: ["iCherri-Mac"])
    ],
    dependencies: [
        .package(path: "../../../packages/ICherriProtocol"),
        .package(path: "../../../packages/ICherriCore"),
        .package(path: "../../../packages/ICherriDesignSystem"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "iCherri-Mac",
            dependencies: [
                "ICherriProtocol",
                "ICherriCore",
                "ICherriDesignSystem",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: ".",
            sources: ["Platform", "Features"]
        )
    ]
)
