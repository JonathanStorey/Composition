// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/IdentityTests.swift
// dependencies: [Extensions/Date.swift, Extensions/UUID.swift, PropertyWrappers/Identity.swift]

// MARK: - Foundation + Observation + os + Security

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security)
import Foundation
import Testing
@testable import Composition

@Suite struct IdentitiesTests {

    @Test func appGroupStoresAndReusesIdentity() {
        let group: String = "group.CompositionTests.\(UUID().uuidString)"
        let identity: UUID = Identities.appGroup(group)
        #expect(identity.version == 7)
        #expect(Identities.appGroup(group) == identity)
        UserDefaults(suiteName: group)?.removeObject(forKey: "Composition.Identity")
    }

    @Test func identityAtURLReplacesUnreadableContents() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "Identity")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try UUID().uuidString.write(to: url, atomically: true, encoding: .utf8)
        let identity: UUID = Identities.identity(at: url)
        #expect(identity.version == 7)
        #expect(try String(contentsOf: url, encoding: .utf8) == identity.uuidString)
    }

    @Test func identityAtURLStoresAndReusesIdentity() throws {
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "Identity")
        let identity: UUID = Identities.identity(at: url)
        #expect(Identities.identity(at: url) == identity)
        #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func storedScopesAreVersion7AndDistinct() {
        #expect([Identities.launch, Identities.install, Identities.device].allSatisfy { $0.version == 7 })
        #expect(Identities.launch != Identities.install)
    }
}
#endif

// MARK: - Foundation + Observation + os + Security + SwiftUI

#if canImport(Foundation) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI)
import SwiftUI

@MainActor
@Suite struct IdentityTests {

    /// Whether this process has no iCloud account, as on test runners.
    private static let hasNoAccount: Bool = FileManager.default.ubiquityIdentityToken == nil

    @Test func dateIsTheTimeInsideTheIdentity() {
        #expect(Date(timestamp: Identity(of: .install).wrappedValue) != nil)
    }

    @Test(.enabled(if: IdentityTests.hasNoAccount, "Needs a process without an iCloud account")) func iCloudIsZeroAndFailsToRefreshWithoutAccount() {
        let identity: Identity = Identity(of: .iCloud)
        #expect(identity.wrappedValue == .zero)
        identity.projectedValue.refresh()
        #expect(identity.projectedValue.status == .failure(.noAccount))
    }

    @Test func localScopesSucceedAtTheirCreation() {
        let identity: Identity = Identity(of: .install)
        let created: Date? = Date(timestamp: identity.wrappedValue)
        identity.projectedValue.refresh()
        #expect(identity.projectedValue.status == created.map(SyncStatus.success))
        #expect(identity.projectedValue.lastSynced == created)
    }

    @Test func scopeIsKept() {
        #expect(Identity(of: .appGroup("group.CompositionTests")).scope == .appGroup("group.CompositionTests"))
    }

    @Test func storedScopesAreSharedAcrossWrappers() {
        #expect(Identity(of: .device).wrappedValue == Identity(of: .device).wrappedValue)
        #expect(Identity(of: .install).wrappedValue == Identity(of: .install).wrappedValue)
        #expect(Identity(of: .launch).wrappedValue == Identity(of: .launch).wrappedValue)
    }

    @Test func viewIsUniquePerWrapper() {
        let first: Identity = Identity(of: .view)
        #expect(first.wrappedValue.version == 7)
        #expect(first.wrappedValue == first.wrappedValue)
        #expect(first.wrappedValue != Identity(of: .view).wrappedValue)
    }
}
#endif
