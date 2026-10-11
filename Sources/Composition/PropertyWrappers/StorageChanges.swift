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
    private let token: Int32?

    /// Starts watching the item for writes from any wrapper, in this process or every process when asked, and for every notification with one of the names.
    init(item: [String], observing names: [Notification.Name] = [], acrossProcesses: Bool = false) {
        self.item = item
        self.token = acrossProcesses ? Self.register(item) : nil
        super.init()
        for name: Notification.Name in [Self.name] + names {
            NotificationCenter.default.addObserver(self, selector: #selector(receive(_:)), name: name, object: nil)
        }
    }

    deinit {
        #if canImport(Darwin)
        if let token { notify_cancel(token) }
        #endif
    }

    /// The notification every wrapper posts after writing, carrying the item it wrote.
    private static let name: Notification.Name = Notification.Name("Composition.StorageChanges.didChange")

    /// The system-wide notification name that wrappers in other processes post after writing the item.
    static func processName(for item: [String]) -> String {
        (["Composition.StorageChanges"] + item).joined(separator: ".")
    }

    /// Relays the item's system-wide notification into this process, returning the registration to cancel.
    private static func register(_ item: [String]) -> Int32? {
        #if canImport(Darwin)
        var token: Int32 = 0
        let status: UInt32 = notify_register_dispatch(processName(for: item), &token, .main) { _ in NotificationCenter.default.post(name: name, object: nil, userInfo: ["item": item]) }
        return status == UInt32(NOTIFY_STATUS_OK) ? token : nil
        #else
        return nil
        #endif
    }

    /// A placeholder property that observers track in place of the stored value.
    private var revision: Void { () }

    /// Tells every wrapper for this item that its value changed, including those in other processes when watching them.
    func post() {
        NotificationCenter.default.post(name: Self.name, object: nil, userInfo: ["item": item])
        #if canImport(Darwin)
        if token != nil { notify_post(Self.processName(for: item)) }
        #endif
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
