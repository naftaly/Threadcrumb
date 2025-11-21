# Threadcrumb

[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS-lightgrey.svg)]()
[![Tests](https://github.com/naftaly/Threadcrumb/actions/workflows/test.yml/badge.svg)](https://github.com/naftaly/Threadcrumb/actions/workflows/test.yml)

## Overview

Threadcrumb simplifies metadata logging by embedding information directly into threads, ensuring their visibility in backtraces during collection. It offers a straightforward approach to enhance traceability, enabling seamless logging of metadata within threads. With Threadcrumb, you can easily integrate metadata logging into your applications, improving their debugging and diagnostic capabilities.

![Threadcrumb](https://github.com/naftaly/Threadcrumb/assets/221626/55ef71a8-b350-4df0-bf4c-29686ac70528)


## Installation

Threadcrumb can be integrated into your project using Swift Package Manager (SPM) or by directly adding the source files to your Xcode project.

### Swift Package Manager

1. In Xcode, select **File** > **Swift Packages** > **Add Package Dependency...**
2. Enter the repository URL `https://github.com/naftaly/Threadcrumb.git`.
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

### Logging

```swift
threadcrumb.log("appstate_active")
```

### Extracting Logs

Threadcrumb provides several methods to access the call stack information:

```swift
// Get the call stack return addresses as UInt64 values (most efficient)
let addresses = threadcrumb.callStackReturnAddresses()

// Get the call stack symbols as strings (computed on-demand from addresses)
let symbols = threadcrumb.callStackSymbols()

// Extract the encoded breadcrumb string from the stack (for testing)
let breadcrumb = threadcrumb.stringLoggingThread()
```

**Performance note:** Only return addresses are stored in memory. Symbols are computed on-demand from addresses when you call `callStackSymbols()`, which uses `dladdr` for symbol resolution. For maximum performance, prefer using `callStackReturnAddresses()` and resolve symbols on the backend when collecting backtraces from MetricKit or other crash reporting systems.

## Requirements

- Swift 6.0+
- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+ / visionOS 1.0+

## License

Threadcrumb is available under the MIT license. See the [LICENSE](LICENSE) file for more information.
