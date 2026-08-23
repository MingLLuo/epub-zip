// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EPUBZip",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "EPUBZipCore", targets: ["EPUBZipCore"]),
    .executable(name: "epubzip", targets: ["EPUBZipCLI"]),
    .executable(name: "EPUBZipApp", targets: ["EPUBZipApp"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/weichsel/ZIPFoundation.git",
      .upToNextMinor(from: "0.9.20")
    )
  ],
  targets: [
    .target(
      name: "EPUBZipCore",
      dependencies: ["ZIPFoundation"]
    ),
    .executableTarget(
      name: "EPUBZipCLI",
      dependencies: ["EPUBZipCore"]
    ),
    .executableTarget(
      name: "EPUBZipApp",
      dependencies: ["EPUBZipCore"]
    ),
    .testTarget(
      name: "EPUBZipCoreTests",
      dependencies: ["EPUBZipCore", "ZIPFoundation"]
    ),
    .testTarget(
      name: "EPUBZipAppTests",
      dependencies: ["EPUBZipApp", "EPUBZipCore"]
    ),
    .testTarget(
      name: "EPUBZipCLITests",
      dependencies: ["EPUBZipCLI", "EPUBZipCore"]
    ),
  ]
)
