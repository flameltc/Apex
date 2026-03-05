// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ApexPlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ApexPlayer", targets: ["ApexPlayer"])
    ],
    targets: [
        .executableTarget(
            name: "ApexPlayer",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "ApexPlayerTests",
            dependencies: ["ApexPlayer"]
        )
    ]
)
