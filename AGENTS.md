# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

`Extension` is a Swift package of reusable extensions, protocols, property wrappers, and SwiftUI view modifiers.

- Swift tools version 6.0. Package minimums: iOS 17, macOS 14.
- Build and test with `swift build` and `swift test`. SwiftUI code only builds on Apple platforms, so run these on macOS.

## Layout

```
Sources/Extension/
├── Extensions/        Extensions on existing types, one file per type (String.swift, View.swift)
├── PropertyWrappers/  One property wrapper per file
├── Protocols/         One protocol per file, with its default implementation
└── ViewModifiers/     One ViewModifier per file
Tests/ExtensionTests/  Mirrors the Sources folder structure
```

## Conventions

### Every file must stand alone

A developer should be able to copy a single file into their own project and have it compile.

- Never depend on code from another file in this package. Inline small helpers instead.
- The only exception is a `View` shortcut for a modifier in `ViewModifiers`. State the dependency in a comment at the top of the file, for example `// Requires CardModifier.swift (in ViewModifiers) alongside this file.`
- Begin standalone files with `// Standalone file: paste it into any Swift project. It has no package dependencies.`
- Mark everything that callers use as `public`.

### Import only what each piece of code needs

- Import Foundation only when the code requires it.
- If only part of a file needs Foundation, wrap that part and its import in `#if canImport(Foundation)` so the rest of the file stays dependency-free.

### Document minimum versions for each extension

- Every extension member gets a doc comment ending in a `Requires:` line that lists its real minimums, even when they are lower than the package minimums. For example, `Requires: Foundation. iOS 9.0+, macOS 10.11+, tvOS 9.0+, watchOS 2.0+.`
- When the minimum is iOS 13 / macOS 10.15 or later, also add `@available(iOS x, macOS x, tvOS x, watchOS x, *)` with the correct version for every platform. Note which API sets the minimum.

### Order members in extension files

Group members under MARK sections, with variables before functions:

```swift
// MARK: - Variables

// MARK: - Functions
```

### Doc comments

Each public declaration gets a `///` doc comment with a short usage example.

### Tests

- Use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Do not use XCTest.
- Place tests in the folder matching the source file, for example `Tests/ExtensionTests/Extensions/StringTests.swift`.
- Every new public API gets at least one test covering its main behavior and one edge case.
