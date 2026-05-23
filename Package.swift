// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "KeepAwake",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "KeepAwake", targets: ["KeepAwake"])
    ],
    targets: [
        .executableTarget(
            name: "KeepAwake"
        ),
        .testTarget(
            name: "KeepAwakeTests",
            dependencies: ["KeepAwake"]
        )
    ],
    swiftLanguageModes: [.v6]
)
