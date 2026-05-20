// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ClassSnap",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "ClassSnap",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.classsnap",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .bookClosed),
            accentColor: .presetColor(.green),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .photoLibrary(intentSystemImageName: "photo")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
