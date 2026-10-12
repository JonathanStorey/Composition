// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StorageFile.swift
// dependencies: []

#if canImport(Foundation) && canImport(os)
import Foundation
import os

/// A value kept as JSON in a file in the app's Application Support folder, written in the background so a change never waits on the disk.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class StorageFile<Contents: Codable & Sendable>: Sendable {

    private let pending: OSAllocatedUnfairLock<Contents?> = OSAllocatedUnfairLock(initialState: nil)
    private let queue: DispatchQueue
    private let url: URL

    /// Creates the file with the name, in a folder kept apart for each app.
    init(_ name: String) {
        self.queue = DispatchQueue(label: "Composition.StorageFile.\(name)", qos: .utility)
        self.url = URL.applicationSupportDirectory.appending(components: Bundle.main.bundleIdentifier ?? "Composition", "Composition", "\(name).json")
    }

    /// The contents last written, once any write still waiting finishes, or `nil` when nothing was written.
    func read() -> Contents? {
        queue.sync {}
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
    }

    /// Writes the contents in the background, where newer contents replace any still waiting to be written.
    func write(_ contents: Contents) {
        let isIdle: Bool = pending.withLock { pending in
            defer { pending = contents }
            return pending == nil
        }
        guard isIdle else { return }
        queue.async { [self] in
            guard let latest: Contents = pending.withLock({ pending in defer { pending = nil }; return pending }), let data: Data = try? JSONEncoder().encode(latest) else { return }
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
    }
}
#endif
