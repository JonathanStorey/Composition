# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

`Composition` is a Swift package of reusable extensions, protocols, property wrappers, and SwiftUI view modifiers.

- Swift tools version 6.0. Package minimums: iOS 17, macOS 14.
- Build and test with `swift build` and `swift test` on macOS, since SwiftUI code only builds on Apple platforms.

## Layout

```
Sources/Composition/
├── Collections/       Custom collection types, one per file (Branch.swift)
├── Extensions/        Extensions on existing types, one file per type (String.swift, View.swift)
├── Macros/            Public macro declarations, one macro per file
├── PropertyWrappers/  One property wrapper per file
├── Protocols/         One protocol per file, with its default implementation
└── ViewModifiers/     One ViewModifier per file
Tests/CompositionTests/  Mirrors the Sources folder structure
```

## Conventions

Every rule applies to test files too.

### Header

Start every file with this header and a blank line:

```swift
// repository: https://github.com/JonathanStorey/Composition
// path: Protocols/Searchable.swift
// dependencies: [Extensions/String.swift]
```

- `path` is relative to the file's target folder (`Sources/Composition/` or `Tests/CompositionTests/`).
- `dependencies` lists, alphabetically and relative to `Sources/Composition/`, every source file whose code this file uses directly, or `[]`. Frameworks and test files are never listed.
- Reuse existing helpers instead of duplicating them, and list their files here.

### Access and availability

- Mark everything callers use `public`. Give everything else the narrowest access that compiles: `private` for use inside its own declaration, `fileprivate` for use within the file, and internal (no modifier) only for use from another file, including tests.
- When code needs iOS 13 / macOS 10.15 or later, add `@available(iOS x, macOS x, tvOS x, watchOS x, *)` with the correct version for every platform, on the member, or on the whole type or extension when every member needs it.

### Member order

- Order members as stored `let`s, stored `var`s, initializers, static variables, static functions, computed instance variables, then instance functions.
- Within each group, order by access (public, internal, fileprivate, private), then alphabetically. Test functions are alphabetical.
- Do not add `// MARK: - Variables` or `// MARK: - Functions`.

### Dependency sections

When only some code in a file needs a framework, split the file:

1. Standard-library code first, with no MARK.
2. Then one section per framework, alphabetically, under `// MARK: - Name`, wrapped in `#if canImport(Name)` with the import inside.
3. Sections needing several frameworks come last, as `// MARK: - Foundation + SwiftUI` and `#if canImport(Foundation) && canImport(SwiftUI)`.

```swift
public extension String {

    /// A Boolean value indicating whether the string is empty or contains only whitespace and newlines.
    var isBlank: Bool { ... }
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

When the whole file needs the same frameworks, wrap it all in one `#if canImport(...)` with the import below it, `#endif` as the last line, and no MARKs. Guard a test file, or an extension of its suite, the same way as the code it tests.

### Calls and declarations

- Keep every call's arguments, and every declaration including its `where` clause, on a single line however long it gets, for example `public extension Picker where Label == Text, SelectionValue: CaseIterable & LabelRepresentable, Content == ForEach<...> {`.
- Use at most one trailing closure, as in `Label(title) { icon }`, never `Label { title } icon: { icon }`. When SwiftUI only offers a multi-closure initializer, pass the closures as labeled arguments, as in `self.init(title: { Text(title) }, icon: icon)`, or add a helper initializer with the one-trailing-closure form.
- Leave a blank line after the opening brace of every type, protocol, and extension.

### Naming

- Name a generic parameter with one capital letter from its protocol and the value for what it is, as in `init<L: LabelRepresentable>(_ label: L)`. Use a named generic parameter instead of `some Protocol` when a `where` clause needs its associated type.
- Give a parameter both an argument label and a parameter name when the label reads better at the call site and the name gives more context inside the declaration, as in `init?(timestamp uuid: UUID)`, called as `Date(timestamp: id)`, or `squashed(with next: Self)`, where `next` says which change comes second.

### Doc comments

Each public declaration gets a single-line `///` summary, with no examples, extra lines, or minimum-version notes.

### Tests

- Use Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), never XCTest.
- Mirror the source path, as in `Tests/CompositionTests/Extensions/StringTests.swift`.
- Every new public API gets a test of its main behavior and one edge case.
