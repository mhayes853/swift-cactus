// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let supportsTelemetry = SwiftSetting.define(
  "SWIFT_CACTUS_SUPPORTS_DEFAULT_TELEMETRY",
  .when(platforms: [.iOS, .macOS])
)

let package = Package(
  name: "swift-cactus",
  platforms: [.iOS(.v13), .macOS(.v11), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
  products: [
    .library(name: "Cactus", targets: ["Cactus"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
    .package(url: "https://github.com/vapor-community/Zip", from: "2.2.7"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(url: "https://github.com/mhayes853/swift-operation", from: "0.3.1"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/apple/swift-log", from: "1.6.4"),
    .package(url: "https://github.com/apple/swift-crypto", from: "4.0.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0")
  ],
  targets: [
    .target(
      name: "Cactus",
      dependencies: [
        "CXXCactusShims",
        .target(name: "cactus_util", condition: .when(platforms: [.iOS, .macOS])),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Zip", package: "Zip"),
        .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
        .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.android]))
      ],
      swiftSettings: [supportsTelemetry]
    ),
    .testTarget(
      name: "CactusTests",
      dependencies: [
        "Cactus",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Operation", package: "swift-operation"),
        .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
      ],
      exclude: ["LanguageModelTests/__Snapshots__", "JSONSchemaTests/__Snapshots__"],
      resources: [.process("Resources")],
      swiftSettings: [supportsTelemetry]
    ),
    .target(
      name: "CXXCactusShims",
      dependencies: [
        .target(name: "CXXCactus", condition: .when(platforms: [.android])),
        .target(
          name: "CXXCactusDarwin",
          condition: .when(platforms: [.iOS, .macOS, .visionOS, .tvOS, .watchOS, .macCatalyst])
        )
      ]
    ),
    .binaryTarget(name: "CXXCactusDarwin", path: "bin/CXXCactusDarwin.xcframework"),
    .binaryTarget(name: "CXXCactus", path: "bin/CXXCactus.artifactbundle"),
    .binaryTarget(name: "cactus_util", path: "bin/cactus_util.xcframework")
  ]
)
