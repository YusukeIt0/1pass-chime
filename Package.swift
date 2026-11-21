// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OnePassChime",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OnePassChime", targets: ["OnePassChime"]),
    ],
    targets: [
        .target(name: "ChimeCore"),
        .executableTarget(name: "OnePassChime", dependencies: ["ChimeCore"]),
        .testTarget(name: "ChimeCoreTests", dependencies: ["ChimeCore"]),
    ]
)
