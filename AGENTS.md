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

### Share code across files

Files may use code from other files in the package. Reuse existing helpers instead of duplicating them, for example `Searchable` uses `String.trimmed`.

### Mark access and availability

- Mark everything that callers use as `public`.
- When code needs iOS 13 / macOS 10.15 or later, add `@available(iOS x, macOS x, tvOS x, watchOS x, *)` with the correct version for every platform. Put it on the member, or on the whole type or extension when every member needs it.

### Order members

- Order members as initializers, static variables, static functions, instance variables, then instance functions. Each group is alphabetical.
- Do not add `// MARK: - Variables` or `// MARK: - Functions`.
- Tests follow the same rule: test functions are alphabetical.

### Separate code by dependency

When some code in a file needs a framework such as Foundation and other code does not, split the file by dependency:

1. Code that needs only the Swift standard library goes first, with no MARK.
2. Each dependency gets its own section below, under a MARK named for the dependency. Put the import below the MARK and wrap the section in `#if canImport(...)`.
3. Order the dependency sections alphabetically by dependency name, for example Foundation before SwiftUI. Sections needing more than one dependency come last, named with `+` (for example `// MARK: - Foundation + SwiftUI`) and wrapped in `#if canImport(A) && canImport(B)`.
4. Within each section, follow the member ordering above.

When everything in a file shares the same imports, as in `View.swift` and `Searchable.swift`, put the imports at the top of the file and add no MARKs.

```swift
public extension String {

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    var isBlank: Bool { ... }

    /// Returns a Boolean value indicating whether the entire string matches a regular expression.
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    func matches(pattern: String) -> Bool { ... }
}

// MARK: - Foundation

#if canImport(Foundation)
import Foundation

public extension String {

    /// The string with leading and trailing whitespace and newlines removed.
    var trimmed: String { ... }
}
#endif
```

### Naming

Give a parameter both an argument label and a parameter name when that reads better at the call site or gives clearer autocomplete hints, for example `init?(timestamp uuid: UUID)`, called as `Date(timestamp: id)`.

### Formatting

- Do not add header comments at the top of files.
- Leave a blank line after the opening brace of every type, protocol, and extension declaration, including in tests.

### Doc comments

Each public declaration gets a single-line `///` summary. Do not add usage examples, extra detail lines, or notes about minimum versions.

### Tests

- Use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`). Do not use XCTest.
- Place tests in the folder matching the source file, for example `Tests/ExtensionTests/Extensions/StringTests.swift`.
- Every new public API gets at least one test covering its main behavior and one edge case.
