//
//  RecentRepositoriesStoreTests.swift
//  MapleTests
//
//  Covers RecentRepositoriesStore: the persistence of open repository paths and
//  the selected repo across launches. Uses an isolated UserDefaults suite.
//

import Foundation
import Testing
@testable import Maple

@MainActor
struct RecentRepositoriesStoreTests {

    private func withStore(_ body: (RecentRepositoriesStore) -> Void) {
        let suiteName = "maple.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(RecentRepositoriesStore(defaults: defaults))
    }

    @Test func savesAndLoadsPaths() {
        withStore { store in
            #expect(store.loadPaths().isEmpty)
            store.save(paths: ["/a", "/b"])
            #expect(store.loadPaths() == ["/a", "/b"])
        }
    }

    @Test func deduplicatesPathsPreservingOrder() {
        withStore { store in
            store.save(paths: ["/a", "/b", "/a", "/c", "/b"])
            #expect(store.loadPaths() == ["/a", "/b", "/c"])
        }
    }

    @Test func capsStoredPaths() {
        withStore { store in
            store.save(paths: (0..<50).map { "/repo/\($0)" })
            #expect(store.loadPaths().count == 20)
            #expect(store.loadPaths().first == "/repo/0")
        }
    }

    @Test func savesAndClearsSelectedPath() {
        withStore { store in
            #expect(store.loadSelectedPath() == nil)
            store.save(selectedPath: "/a")
            #expect(store.loadSelectedPath() == "/a")
            store.save(selectedPath: nil)
            #expect(store.loadSelectedPath() == nil)
        }
    }
}
