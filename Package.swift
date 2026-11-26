// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MBoardCore",
    products: [.library(name: "MBoardCore", targets: ["MBoardCore"])],
    targets: [
        .target(name: "MBoardCore", path: "Core", resources: [.copy("Resources/BurmeseWords.txt"), .copy("Resources/BurmeseWords-LICENSE.txt")]),
        .testTarget(name: "MBoardCoreTests", dependencies: ["MBoardCore"], path: "Tests")
    ]
)
