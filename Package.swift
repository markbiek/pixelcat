// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PixelCat",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PixelCatCore"),
        .executableTarget(
            name: "PixelCat",
            dependencies: ["PixelCatCore"]
        ),
        .testTarget(
            name: "PixelCatCoreTests",
            dependencies: ["PixelCatCore"]
        ),
    ]
)
