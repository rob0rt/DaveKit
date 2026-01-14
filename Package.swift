// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DaveKit",
    products: [
        .library(
            name: "DaveKit",
            targets: ["DaveKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.9.0")
    ],
    targets: [
        .target(
            name: "DaveKit",
            dependencies: [
                .target(name: "libdave"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        .target(
            name: "libdave",
            dependencies: [
                .target(name: "mlspp"),
                .target(name: "bytes"),
                .target(name: "tls_syntax"),
            ],
            path: "Sources/CLibdave/libdave/cpp",
            exclude: [
                "test",
                "src/dave/mls/detail/persisted_key_pair_apple.cpp",
                "src/dave/mls/detail/persisted_key_pair_null.cpp",
                "src/dave/mls/detail/persisted_key_pair_win.cpp",
                "src/dave/bindings_wasm.cpp",
                "src/dave/boringssl_cryptor.cpp",
                "src/dave/boringssl_cryptor.h",
            ],
            sources: ["src"],
            publicHeadersPath: "includes",
            cxxSettings: [
                .headerSearchPath("src"),
            ]
        ),

        .target(
            name: "mlspp",
            dependencies: [
                .target(name: "hpke"),
                .target(name: "bytes"),
                .target(name: "tls_syntax"),
            ],
            path: "Sources/CMLS/mlspp",
            exclude: ["test"],
            sources: ["src"],
            cxxSettings: [
                .define("WITH_PQ")
            ],
        ),

        .target(
            name: "mlspp_namespace",
            path: "Sources/CMLS/namespace",
            publicHeadersPath: ".",
        ),

        .target(
            name: "hpke",
            dependencies: [
                .target(name: "mlspp_namespace"),
                .target(name: "bytes"),
                .target(name: "tls_syntax"),
                .target(name: "json"),
            ],
            path: "Sources/CMLS/mlspp/lib/hpke",
            exclude: ["test"],
            sources: ["src"],
        ),

        .target(
            name: "bytes",
            dependencies: [
                .target(name: "mlspp_namespace"),
                .target(name: "tls_syntax"),
            ],
            path: "Sources/CMLS/mlspp/lib/bytes",
            exclude: ["test"],
            sources: ["src"],
        ),

        .target(
            name: "tls_syntax",
            dependencies: [.target(name: "mlspp_namespace")],
            path: "Sources/CMLS/mlspp/lib/tls_syntax",
            exclude: ["test"],
            sources: ["src"],
        ),

        .target(
            name: "json",
            path: "Sources/CJson/json/single_include",
            publicHeadersPath: ".",
        ),

        .testTarget(
            name: "DaveKitTests",
            dependencies: ["DaveKit"]
        ),
    ]
)
