// swift-tools-version: 5.9
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

// Swift 6 language mode. Set here rather than in the initializer so that SwiftPM versions
// before 6.0, which reject language version 6, can still read the manifest.
#if compiler(>=6)
package.swiftLanguageVersions = [.version("6")]
#endif
