// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-cactus",
  products: [
    .library(name: "CactusEngine", targets: ["CactusEngine"])
  ],
  targets: [
    .target(name: "CactusEngine"),
    .testTarget(name: "CactusEngineTests", dependencies: ["CactusEngine"])
  ]
)
