import SwiftUI
import Testing
@testable import Extension

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SampleAction: CaseIterable, LabelRepresentable {

    case archive
    case delete
    case share

    var role: ButtonRole? {
        self == .delete ? .destructive : nil
    }

    var systemImage: String {
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

private struct PlainItem: LabelRepresentable {

    let systemImage = "star"
    let title: LocalizedStringResource = "Favorite"
}

@Suite struct LabelRepresentableTests {

    @Test func roleDefaultsToNil() {
        #expect(PlainItem().role == nil)
    }

    @Test func roleCanBeOverridden() {
        #expect(SampleAction.delete.role == .destructive)
        #expect(SampleAction.share.role == nil)
    }

    @Test func symbolsExist() {
        for action in SampleAction.allCases {
            #if canImport(UIKit)
            #expect(UIImage(systemName: action.systemImage) != nil, "Missing symbol: \(action.systemImage)")
            #elseif canImport(AppKit)
            #expect(NSImage(systemSymbolName: action.systemImage, accessibilityDescription: nil) != nil, "Missing symbol: \(action.systemImage)")
            #endif
        }
    }

    @Test func titleResolvesToText() {
        #expect(String(localized: SampleAction.share.title) == "Share")
    }
}
