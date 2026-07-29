//
//  RecentRepositoriesStore.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

/// Persists which repositories are open and which one is selected, so they
/// survive relaunches. Stores plain paths (the app runs without the sandbox, so
/// no security-scoped bookmarks are needed) in UserDefaults, capped to a sane
/// maximum. Injectable defaults keep it unit testable.
struct RecentRepositoriesStore {
    private let defaults: UserDefaults
    private let maxCount = 20

    private enum Key {
        static let paths = "recentRepositoryPaths"
        static let selected = "selectedRepositoryPath"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Open repository paths, in order, de-duplicated and capped.
    func loadPaths() -> [String] {
        defaults.stringArray(forKey: Key.paths) ?? []
    }

    func save(paths: [String]) {
        var seen = Set<String>()
        let unique = paths.filter { seen.insert($0).inserted }
        defaults.set(Array(unique.prefix(maxCount)), forKey: Key.paths)
    }

    func loadSelectedPath() -> String? {
        defaults.string(forKey: Key.selected)
    }

    func save(selectedPath: String?) {
        defaults.set(selectedPath, forKey: Key.selected)
    }
}
