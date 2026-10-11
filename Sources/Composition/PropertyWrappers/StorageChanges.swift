// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/StorageChanges.swift
// dependencies: []

#if canImport(Foundation) && canImport(Observation)
import Foundation
import Observation

/// Tells observers, such as a view's body, when a stored item changes, whether a wrapper wrote it or the system changed it.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
final class StorageChanges: NSObject, Observable, Sendable {

    private let item: [String]
    private let registrar: ObservationRegistrar = ObservationRegistrar()

    /// Starts watching the item for writes from any wrapper, and for every notification with one of the names.
    init(item: [String], observing names: [Notification.Name] = []) {
        self.item = item
        super.init()
        for name: Notification.Name in [Self.name] + names {
            NotificationCenter.default.addObserver(self, selector: #selector(receive(_:)), name: name, object: nil)
        }
    }

    /// The notification every wrapper posts after writing, carrying the item it wrote.
    private static let name: Notification.Name = Notification.Name("Composition.StorageChanges.didChange")

    /// A placeholder property that observers track in place of the stored value.
    private var revision: Void { () }

    /// Tells every wrapper for this item that its value changed.
    func post() {
        NotificationCenter.default.post(name: Self.name, object: nil, userInfo: ["item": item])
    }

    /// Registers the current observer for changes to the item.
    func track() {
        registrar.access(self, keyPath: \.revision)
    }

    /// Notifies observers when the notification is a system change or a write to this item.
    @objc private func receive(_ notification: Notification) {
        guard notification.name != Self.name || notification.userInfo?["item"] as? [String] == item else { return }
        registrar.withMutation(of: self, keyPath: \.revision) {}
    }
}
#endif
