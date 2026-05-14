// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "direct-encoding",
    platforms: [
      .macOS(.v11),
    ],
    products: [
        .library(
            name: "DirectEncoding",
            targets: ["DirectEncoding"],
        ),
    ],
    dependencies: [
      .package(url: "https://github.com/vinceplusplus/pointer-kit.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "DirectEncoding",
            dependencies: [
              .product(name: "PointerKit", package: "pointer-kit"),
            ],
        ),
        .testTarget(
            name: "DirectEncodingTests",
            dependencies: [
              "DirectEncoding",
              .product(name: "PointerKit", package: "pointer-kit"),
            ],
        ),
    ],
)
