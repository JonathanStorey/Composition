#if canImport(SwiftUI)
import SwiftUI
import Testing
@testable import Composition

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SampleAction: CaseIterable, LabelRepresentable {

    case archive
    case delete
    case share

    var help: LocalizedStringResource? {
        self == .delete ? "Permanently removes the item" : nil
    }

    var icon: Image {
        Image(systemName: symbolName)
    }

    var role: ButtonRole? {
        self == .delete ? .destructive : nil
    }

    var symbolName: String {
        switch self {
        case .archive: "archivebox"
        case .delete: "trash"
        case .share: "square.and.arrow.up"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .archive: "Archive"
        case .delete: "Delete"
        case .share: "Share"
        }
    }
}

enum SampleStatus: CaseIterable, LabelRepresentable {

    case offline
    case online

    @ViewBuilder var icon: some View {
        switch self {
        case .offline: Image(systemName: "wifi.slash")
        case .online: Circle()
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .offline: "Offline"
        case .online: "Online"
        }
    }
}

private struct PlainItem: LabelRepresentable {

    let icon = Image(systemName: "star")
    let title: LocalizedStringResource = "Favorite"
}

@Suite struct LabelRepresentableTests {

    @Test func helpCanBeOverridden() throws {
        let help = try #require(SampleAction.delete.help)
        #expect(String(localized: help) == "Permanently removes the item")
        #expect(SampleAction.share.help == nil)
    }

    @Test func helpDefaultsToNil() {
        #expect(PlainItem().help == nil)
    }

    @Test func iconDefaultsToImageType() {
        #expect(PlainItem.Icon.self == Image.self)
        #expect(PlainItem().icon == Image(systemName: "star"))
    }

    @Test func roleCanBeOverridden() {
        #expect(SampleAction.delete.role == .destructive)
        #expect(SampleAction.share.role == nil)
    }

    @Test func roleDefaultsToNil() {
        #expect(PlainItem().role == nil)
        #expect(SampleStatus.online.role == nil)
    }

    @Test func symbolsExist() {
        for action in SampleAction.allCases {
            #if canImport(UIKit)
            #expect(UIImage(systemName: action.symbolName) != nil, "Missing symbol: \(action.symbolName)")
            #elseif canImport(AppKit)
            #expect(NSImage(systemSymbolName: action.symbolName, accessibilityDescription: nil) != nil, "Missing symbol: \(action.symbolName)")
            #endif
        }
    }

    @Test func titleResolvesToText() {
        #expect(String(localized: SampleAction.share.title) == "Share")
    }
}
#endif
