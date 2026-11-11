// swift-tools-version: 5.9

// Open this folder in Xcode (File ▸ Open… ▸ PaperizeDemo.swiftpm) and run it on an iOS
// simulator or device. It links the Paperize package from the repository root.

import AppleProductTypes
import PackageDescription

let package = Package(
    name: "PaperizeDemo",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "PaperizeDemo",
            targets: ["AppModule"],
            bundleIdentifier: "dev.paperize.demo",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .openBook),
            accentColor: .presetColor(.indigo),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "Paperize", package: "Paperize")
            ],
            path: "."
        )
    ]
)
