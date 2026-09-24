// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "swift-server-control",
    platforms: [
      .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/apple/swift-system.git", "1.4.0"..."1.4.2")
    ],
    targets: [
        .executableTarget(
            name: "GsocTest",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SystemPackage", package: "swift-system")
            ]
        )
    ]
)
