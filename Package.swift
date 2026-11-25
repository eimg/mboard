// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MBoardCore",
    products: [.library(name: "MBoardCore", targets: ["MBoardCore"])],
    targets: [
        .target(name: "MBoardCore", path: "Core"),
        .testTarget(name: "MBoardCoreTests", dependencies: ["MBoardCore"], path: "Tests")
    ]
)
