// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Paperize",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Paperize", targets: ["Paperize"])
    ],
    targets: [
        .target(name: "Paperize", resources: [.process("PrivacyInfo.xcprivacy")]),
        .testTarget(name: "PaperizeTests", dependencies: ["Paperize"])
    ]
)
