#!/bin/zsh
set -eu
# Compile the production widget cache without changing Xcode target membership.
project_root="${0:A:h:h}"
harness_dir="$(mktemp -d /private/tmp/currency-widget-tests.XXXXXX)"
trap 'rm -rf "$harness_dir"' EXIT
mkdir -p "$harness_dir/Sources/WidgetCacheCore" "$harness_dir/Tests/WidgetCacheCoreTests"
cp "$project_root/CurrencyConverterWidget/CurrencyConverterWidget.swift" "$harness_dir/Sources/WidgetCacheCore/"
cp "$project_root/scripts/WidgetCacheTests.swift" "$harness_dir/Tests/WidgetCacheCoreTests/"
cat > "$harness_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "WidgetCacheRegression",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WidgetCacheCore", swiftSettings: [.define("WIDGET_CACHE_TESTING")]),
        .testTarget(name: "WidgetCacheCoreTests", dependencies: ["WidgetCacheCore"])
    ]
)
PACKAGE
swift test --package-path "$harness_dir"
