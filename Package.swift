// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YomuCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "YomuCore", targets: ["YomuCore"])],
    targets: [
        .target(name: "YomuCore", resources: [.process("Resources")],
                linkerSettings: [.linkedLibrary("sqlite3"), .linkedLibrary("z")]),
        .testTarget(name: "YomuCoreTests", dependencies: ["YomuCore"], resources: [.copy("Fixtures")])
    ]
)
