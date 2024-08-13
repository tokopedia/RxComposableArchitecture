// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RxComposableArchitecture",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "RxComposableArchitecture",
            targets: ["RxComposableArchitecture"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift", from: "5.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.14.0"),
        .package(name: "Benchmark", url: "https://github.com/google/swift-benchmark", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.8.5"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "0.9.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "0.7.0"),
        .package(url: "https://github.com/jeffersonsetiawan/RxCombine", revision: "0b984ee089e29736b7f07df03b3af667683deefd")
//        .package(url: "https://github.com/jeffersonsetiawan/RxCombine", branch: "rxswift5")
    ],
    targets: [
        .target(
            name: "RxComposableArchitecture",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRelay", package: "RxSwift"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "RxCombine", package: "RxCombine"),
            ]
        ),
        .testTarget(
            name: "RxComposableArchitectureTests",
            dependencies: [
                "RxComposableArchitecture",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
    ]
)
