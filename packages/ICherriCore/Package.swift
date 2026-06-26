// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ICherriCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ICherriCore", targets: ["ICherriCore"])
    ],
    dependencies: [
        .package(path: "../ICherriProtocol"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.2"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.3.1")
    ],
    targets: [
        .target(
            name: "ICherriCore",
            dependencies: [
                "ICherriProtocol",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Factory", package: "Factory")
            ],
            path: "Sources/ICherriCore"
        ),
        .testTarget(
            name: "ICherriCoreTests",
            dependencies: ["ICherriCore"],
            path: "Tests/ICherriCoreTests"
        )
    ]
)
