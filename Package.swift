// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TransmissionAsyncMidi",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TransmissionAsyncMidi",
            targets: ["TransmissionAsyncMidi"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/orchetect/MIDIKit", from: "0.8.11"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionAsync", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TransmissionAsyncMidi",
            dependencies: [
                "MIDIKit",
                "TransmissionAsync",
            ]
        ),
        .testTarget(
            name: "TransmissionAsyncMidiTests",
            dependencies: ["TransmissionAsyncMidi"]),
    ]
)
