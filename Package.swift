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
            targets: ["RxComposableArchitecture"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift", from: "5.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "0.8.1"),
    ],
    targets: [
        .target(
            name: "RxComposableArchitecture",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxRelay", package: "RxSwift"),
            ]),
        .testTarget(
            name: "RxComposableArchitectureTests",
            dependencies: ["RxComposableArchitecture"]),
    ]
)
