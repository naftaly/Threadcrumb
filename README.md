# Threadcrumb

[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)]()

## Overview

Threadcrumb simplifies metadata logging by embedding information directly into threads, ensuring their visibility in backtraces during collection. It offers a straightforward approach to enhance traceability, enabling seamless logging of metadata within threads. With Threadcrumb, you can easily integrate metadata logging into your applications, improving their debugging and diagnostic capabilities.

## Installation

Threadcrumb can be integrated into your project using Swift Package Manager (SPM) or by directly adding the source files to your Xcode project.

### Swift Package Manager

1. In Xcode, select **File** > **Swift Packages** > **Add Package Dependency...**
2. Enter the repository URL `https://github.com/naftaly/threadcrumb.git`.
3. Specify the version or branch you want to use.
4. Follow the prompts to complete the integration.

### Manual Integration

1. Download the Threadcrumb source files.
2. Drag and drop the source files into your Xcode project.
3. Make sure to add the necessary import statements where you want to use Threadcrumb.

## Usage

### Creating a Threadcrumb Instance

```swift
let threadcrumb = Threadcrumb(identifier: "com.crumb.appstate")
```

### Logging Static Information

```swift
threadcrumb.log("App Started")
```

### Logging a Formatted Strings

```swift
let appstate = "active"
threadcrumb.log("appstate_%@", appstate)
```

### Extracting Logs

See `Threadcrumb.stringLoggingThread` for an example how to extract your logs from a stacktrace.
You might want to do this on the backend when collecting backtraces from MetricKit for example.

## Requirements

- Swift 5.0+
- iOS 16.0+ / macOS 10.15+ / tvOS 16.0+ / watchOS 6.0+

## License

Threadcrumb is available under the MIT license. See the [LICENSE](LICENSE) file for more information.
