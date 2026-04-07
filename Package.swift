// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "local-mlx-chat-core",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocalMLXChatCore",
            targets: ["LocalMLXChatCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", exact: "2.31.3"),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.31.3")
    ],
    targets: [
        .target(
            name: "LocalMLXChatCore",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXRandom", package: "mlx-swift")
            ]
        ),
        .testTarget(
            name: "LocalMLXChatCoreTests",
            dependencies: ["LocalMLXChatCore"]
        )
    ]
)
