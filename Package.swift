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
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", revision: "8c9dd6391139242261bcf27d253c326f9cf2d567"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.31.3"),
        .package(url: "https://github.com/DePasqualeOrg/swift-tokenizers-mlx", branch: "main", traits: [.trait(name: "Swift")])
    ],
    targets: [
        .target(
            name: "LocalMLXChatCore",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLMTokenizers", package: "swift-tokenizers-mlx")
            ]
        ),
        .testTarget(
            name: "LocalMLXChatCoreTests",
            dependencies: ["LocalMLXChatCore"]
        )
    ]
)
