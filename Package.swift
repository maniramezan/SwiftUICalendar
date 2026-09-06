// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let tcaDependencies: [Package.Dependency] = [
  .package(url: "https://github.com/pointfreeco/combine-schedulers", from: "1.2.2"),
  .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.17.1"),
  .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.1.1"),
  .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.11.2"),
  .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.1"),
  .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.10.0"),
  .package(url: "https://github.com/pointfreeco/swift-perception", from: "2.0.12"),
  .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),

  .package(
    url: "https://github.com/pointfreeco/swift-composable-architecture", "1.26.2"..<"1.27.0",
    traits: []),
]

let package = Package(
  name: "SwiftUICalendar",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "SwiftUICalendar",
      targets: ["SwiftUICalendar"]),
    .library(name: "SwiftUICalendarTCA", targets: ["SwiftUICalendarTCA"]),
  ],
  traits: [
    .trait(name: "TCA", description: "Build the optional Composable Architecture integration")
  ],
  dependencies: [
    .package(
      url: "https://github.com/maniramezan/SwiftCommons",
      .upToNextMajor(from: "0.3.0")
    ),
    .package(
      url: "https://github.com/maniramezan/SwiftUIComponents",
      .upToNextMajor(from: "0.2.0")
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-snapshot-testing",
      from: "1.19.3"
    ),
  ] + tcaDependencies,
  targets: [
    .target(
      name: "SwiftUICalendar",
      dependencies: [
        "SwiftCommons",
        .product(name: "Components", package: "SwiftUIComponents"),
        .product(name: "DesignSystem", package: "SwiftUIComponents"),
      ],
      exclude: ["SwiftUICalendar.docc", "Resources/Localizable.xcstrings"],
      resources: [
        .process("Resources")
      ]
    ),
    .target(
      name: "SwiftUICalendarTCA",
      dependencies: [
        "SwiftUICalendar",
        .product(name: "Clocks", package: "swift-clocks", condition: .when(traits: ["TCA"])),
        .product(name: "CasePaths", package: "swift-case-paths", condition: .when(traits: ["TCA"])),
        .product(
          name: "Perception", package: "swift-perception", condition: .when(traits: ["TCA"])),
        .product(
          name: "ComposableArchitecture", package: "swift-composable-architecture",
          condition: .when(traits: ["TCA"])),
      ]),
    .testTarget(
      name: "SwiftUICalendarTCATests",
      dependencies: [
        "SwiftUICalendarTCA",
        .product(
          name: "ComposableArchitecture", package: "swift-composable-architecture",
          condition: .when(traits: ["TCA"])),
      ]),
    .testTarget(
      name: "SwiftUICalendarTests",
      dependencies: [
        "SwiftUICalendarTCA",
        .product(
          name: "ComposableArchitecture", package: "swift-composable-architecture",
          condition: .when(traits: ["TCA"])),
        "SwiftUICalendar",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: ["Snapshot/__Snapshots__"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
