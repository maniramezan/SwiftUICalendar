// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftUICalendar",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "SwiftUICalendar",
      targets: ["SwiftUICalendar"])
  ],
  dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftCommons.git", branch: "main"),
    .package(url: "https://github.com/maniramezan/SwiftUIComponents", branch: "main"),
    .package(
      url: "https://github.com/pointfreeco/swift-snapshot-testing",
      from: "1.18.0"
    ),
  ],
  targets: [
    .target(
      name: "SwiftUICalendar",
      dependencies: ["SwiftCommons", .product(name: "Components", package: "SwiftUIComponents")],
      resources: [
        .process("Resources/Localizable.xcstrings")
      ]
    ),
    .testTarget(
      name: "SwiftUICalendarTests",
      dependencies: [
        "SwiftUICalendar",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["Snapshot/__Snapshots__"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
