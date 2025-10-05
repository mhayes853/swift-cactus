// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-cactus",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
  products: [
    .library(name: "CactusEngine", targets: ["CactusEngine"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
    .package(url: "https://github.com/vapor-community/Zip", from: "2.2.7"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3")
  ],
  targets: [
    .target(name: "CactusEngine", dependencies: [.product(name: "Zip", package: "Zip")]),
    .testTarget(
      name: "CactusEngineTests",
      dependencies: [
        "CactusEngine",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "CustomDump", package: "swift-custom-dump")
      ]
    )
  ]
)
