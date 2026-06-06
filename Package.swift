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
    // Pinned to exact revisions for reproducible builds (these repos are not yet tagged).
    // Switch to `from: "x.y.z"` once SwiftCommons / SwiftUIComponents publish versioned releases.
    .package(
      url: "https://github.com/maniramezan/SwiftCommons.git",
      revision: "4c51afbf713a7b992fa38de03142fc3af84416a1"
    ),
    .package(
      url: "https://github.com/maniramezan/SwiftUIComponents",
      revision: "eea6f744700a9c11a83edc63ff418c977ca7ec0c"
    ),
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
