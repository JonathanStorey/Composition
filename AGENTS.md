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

### Mark minimum versions with `@available`

- When code needs iOS 13 / macOS 10.15 or later, add `@available(iOS x, macOS x, tvOS x, watchOS x, *)` with the correct version for every platform.
- In the doc comment, note which API sets the minimum.
- Do not add `@available` or version notes for code with lower minimums.

### Order members in extension files

Every section lists variables before functions, each group in alphabetical order.

1. **Top half: standard library only.** One extension with `// MARK: - Variables` and `// MARK: - Functions`. Members that need a newer OS version stay here, sorted alphabetically with the rest, with `@available` on the member itself.
2. **Bottom half: one section per dependency.** Members that need a framework such as Foundation go below, under a MARK named for the dependency. Put the import below the MARK and wrap the section in `#if canImport(...)`, so the rest of the file stays dependency-free.
3. **Order the dependency sections alphabetically by dependency name.** Sections needing more than one dependency come after all single-dependency sections, named with `+` (for example `// MARK: - Foundation + SwiftUI`) and wrapped in `#if canImport(A) && canImport(B)`.
4. **These are the only MARKs.** Do not add Variables or Functions MARKs inside dependency sections, and do not add MARKs for OS versions.
5. **Leave out empty sections.**

```swift
public extension String {

    // MARK: - Variables

    var isBlank: Bool { ... }

    // MARK: - Functions

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    func matches(pattern: String) -> Bool { ... }
}

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

public extension String {
    var trimmed: String { ... }
}
#endif
```

If every member in a file shares the same dependency, as `View.swift` does with SwiftUI, import it at the top of the file as usual and use only the Variables and Functions sections.

### Doc comments

Each public declaration gets a `///` doc comment with a short usage example.

### Tests

- Use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Do not use XCTest.
- Place tests in the folder matching the source file, for example `Tests/ExtensionTests/Extensions/StringTests.swift`.
- Every new public API gets at least one test covering its main behavior and one edge case.
