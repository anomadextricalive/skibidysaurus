// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Skibidysaurus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Skibidysaurus", targets: ["SkibidysaurusApp"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SkibidysaurusApp",
            dependencies: [],
            path: "SkibidysaurusApp"
        )
    ]
)
