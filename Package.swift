// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flow_CLI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .executable(name: "Flow_CLI", targets: ["Flow_CLI"])
    ],
    targets: [
        .executableTarget(
            name: "Flow_CLI",
            dependencies: [],
            path: "Flow_CLI",
            resources: [
                .copy("models/best_conf0.1.mlpackage"),
                .copy("models/yolov11s-doclaynet.mlpackage")
            ],
            swiftSettings: [
                .define("CLI_MODE")
            ]
        )
    ]
)
