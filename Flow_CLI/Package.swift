// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flow_CLI",
    platforms: [
        .macOS(.v14),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "Flow_CLI", targets: ["Flow_CLI"])
    ],
    targets: [
        .executableTarget(
            name: "Flow_CLI",
            dependencies: [],
            resources: [
                .copy("Models")
            ],
            swiftSettings: [
                .define("CLI_MODE")
            ]
        )
    ]
)
