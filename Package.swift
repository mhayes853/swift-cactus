// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let StreamParsing128BitIntegers =
  "AvailabilityMacro=StreamParsing128BitIntegers:macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0"

let package = Package(
  name: "swift-cactus",
  platforms: [.iOS(.v13), .macOS(.v11), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
  products: [
    .library(name: "CactusCore", targets: ["CactusCore"]),
    .library(name: "Cactus", targets: ["Cactus"]),
    .library(name: "CXXCactusShims", targets: ["CXXCactusShims"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.7"),
    .package(url: "https://github.com/vapor-community/Zip", from: "2.2.7"),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(url: "https://github.com/mhayes853/swift-operation", from: "0.3.1"),
    .package(url: "https://github.com/mhayes853/swift-stream-parsing", from: "0.1.3"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.4"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.4.3"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"603.0.0"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0")
  ],
  targets: [
    .target(
      name: "CactusCore",
      dependencies: [
        "CXXCactusShims",
        .product(name: "Zip", package: "Zip"),
        .product(name: "StreamParsingCore", package: "swift-stream-parsing")
      ],
      swiftSettings: [.enableExperimentalFeature(StreamParsing128BitIntegers)]
    ),
    .target(
      name: "Cactus",
      dependencies: [
        "CactusCore",
        "CactusMacros",
        .product(name: "StreamParsing", package: "swift-stream-parsing")
      ]
    ),
    .macro(
      name: "CactusMacros",
      dependencies: [
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftDiagnostics", package: "swift-syntax")
      ]
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
      resources: [.copy("Resources")],
      swiftSettings: [.enableExperimentalFeature(StreamParsing128BitIntegers)]
    ),
    .testTarget(
      name: "CactusMacrosTests",
      dependencies: [
        "CactusMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing")
      ]
    ),
    .target(
      name: "CXXCactusShims",
      dependencies: [
        .target(name: "CXXCactus", condition: .when(platforms: [.android, .linux])),
        .target(
          name: "CXXCactusDarwin",
          condition: .when(platforms: [.iOS, .macOS, .visionOS, .tvOS, .watchOS, .macCatalyst])
        )
      ],
      linkerSettings: [
        .linkedLibrary("c++_shared", .when(platforms: [.android]))
      ]
    ),
    .binaryTarget(name: "CXXCactusDarwin", path: "bin/CXXCactusDarwin.xcframework.zip"),
    .binaryTarget(name: "CXXCactus", path: "bin/CXXCactus.artifactbundle.zip")
  ]
)
