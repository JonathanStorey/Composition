// repository: https://github.com/JonathanStorey/Composition
// path: PropertyWrappers/IdentityTests.swift
// dependencies: [Extensions/Date.swift, Extensions/UUID.swift, PropertyWrappers/Identity.swift, PropertyWrappers/SyncedStorage.swift]

// MARK: - CloudKit + Foundation + Network + Observation + os + Security + UniformTypeIdentifiers

#if canImport(CloudKit) && canImport(Foundation) && canImport(Network) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(UniformTypeIdentifiers)
import CloudKit
import Foundation
import Testing
@testable import Composition

@Suite struct IdentitiesTests {

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

@Suite struct InternetConnectionTests {

    @Test func confirmFailsAsABadResponseWhenAPortalAnswers() async throws {
        let key: String = UUID().uuidString
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try "<HTML><BODY>Sign in to Wi-Fi</BODY></HTML>".write(to: url, atomically: true, encoding: .utf8)
        let connection: InternetConnection = InternetConnection(checking: url, storedUnder: key)
        await connection.confirm()?.value
        guard case .failure(let error) = connection.status else { Issue.record("Expected a failure"); return }
        #expect((error as? URLError)?.code == .badServerResponse)
        #expect(UserDefaults.standard.string(forKey: key) == nil)
    }

    @Test func confirmFailsWithTheNetworkErrorWhenThePageWontLoad() async {
        let key: String = UUID().uuidString
        let connection: InternetConnection = InternetConnection(checking: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString), storedUnder: key)
        await connection.confirm()?.value
        guard case .failure(let error) = connection.status else { Issue.record("Expected a failure"); return }
        #expect(error is URLError)
        #expect(UserDefaults.standard.string(forKey: key) == nil)
    }

    @Test func confirmRenewsTheIdentityWhenThePageSaysSuccess() async throws {
        let key: String = UUID().uuidString
        let url: URL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try "<HTML><BODY>Success</BODY></HTML>".write(to: url, atomically: true, encoding: .utf8)
        let connection: InternetConnection = InternetConnection(checking: url, storedUnder: key)
        await connection.confirm()?.value
        let identity: UUID? = UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
        #expect(identity?.version == 7)
        guard case .success(let date) = connection.status else { Issue.record("Expected a success"); return }
        #expect(date == identity.flatMap(Date.init(timestamp:)))
        UserDefaults.standard.removeObject(forKey: key)
    }

    @Test func statusStartsUnknownBeforeTheFirstCheck() {
        guard case .unknown = InternetConnection(storedUnder: UUID().uuidString).status else { Issue.record("Expected unknown"); return }
    }
}
#endif

// MARK: - CloudKit + Foundation + Network + Observation + os + Security + SwiftUI + UniformTypeIdentifiers

#if canImport(CloudKit) && canImport(Foundation) && canImport(Network) && canImport(Observation) && canImport(os) && canImport(Security) && canImport(SwiftUI) && canImport(UniformTypeIdentifiers)
import SwiftUI

@MainActor
@Suite struct IdentityTests {

    @Test func dateIsTheTimeInsideTheIdentity() {
        #expect(Date(timestamp: Identity(of: .install).wrappedValue) != nil)
    }

    #if os(macOS)
    @Test func iCloudStaysZeroWhenARefreshFails() {
        let identity: Identity = Identity(of: .iCloud)
        identity.refresh()
        #expect(identity.wrappedValue == .zero)
        #expect(identity.lastSynced == nil)
        guard case .failure(let error) = identity.status else { Issue.record("Expected a failure"); return }
        #expect((error as? CKError)?.code == .missingEntitlement)
    }
    #endif

    @Test func localScopesSucceedAtTheirCreation() {
        let identity: Identity = Identity(of: .install)
        let created: Date? = Date(timestamp: identity.wrappedValue)
        identity.projectedValue.refresh()
        #expect(identity.projectedValue.lastSynced == created)
        guard case .success(let date) = identity.projectedValue.status else { Issue.record("Expected a success"); return }
        #expect(date == created)
    }

    @Test func refreshKeepsScopesFixedForTheirLifetime() {
        let identities: [UUID] = [Identity(of: .device), Identity(of: .install), Identity(of: .launch)].map(\.wrappedValue)
        [Identity(of: .device), Identity(of: .install), Identity(of: .launch)].forEach { $0.refresh() }
        #expect([Identity(of: .device), Identity(of: .install), Identity(of: .launch)].map(\.wrappedValue) == identities)
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
