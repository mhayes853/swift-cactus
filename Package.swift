// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-cactus",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
  products: [
    .library(name: "Cactus", targets: ["Cactus"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
    .package(url: "https://github.com/vapor-community/Zip", from: "2.2.7"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(url: "https://github.com/mhayes853/swift-operation", from: "0.1.0"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.4")
  ],
  targets: [
    .binaryTarget(name: "CactusUtil", path: "CactusUtil.artifactbundle"),
    .target(
      name: "CXXCactus",
      exclude: [
        "cactus/apple", "cactus/android", "cactus/assets", "cactus/tests", "cactus/tools",
        "cactus/.gitignore", "cactus/LICENSE", "cactus/README.md"
      ],
      cxxSettings: [.unsafeFlags(["-std=c++20", "-O3"])],
    ),
    .target(
      name: "Cactus",
      dependencies: [
        "CXXCactus",
        .target(name: "CactusUtil", condition: .when(platforms: [.iOS])),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Zip", package: "Zip"),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
      ]
    ),
    .testTarget(
      name: "CactusTests",
      dependencies: [
        "Cactus",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Operation", package: "swift-operation")
      ],
      exclude: ["__Snapshots__"]
    )
  ]
)
