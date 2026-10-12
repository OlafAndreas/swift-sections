// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SwiftSections",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "SwiftSections", targets: ["SwiftSections"]),
    ],
    targets: [
        .target(name: "SwiftSections", dependencies: ["SwiftSectionsShim"]),
        // ELF only: enumerates loaded images with dl_iterate_phdr and reads section headers
        // from each image's file, because ELF section headers are not mapped at runtime.
        .target(name: "SwiftSectionsShim"),
        .testTarget(name: "SwiftSectionsTests", dependencies: ["SwiftSections"]),
    ]
)
