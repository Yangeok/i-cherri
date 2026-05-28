// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ICherriProtocol",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ICherriProtocol", targets: ["ICherriProtocol"])
    ],
    targets: [
        .target(
            name: "ICherriProtocol",
            path: "Sources/ICherriProtocol"
        )
    ]
)
