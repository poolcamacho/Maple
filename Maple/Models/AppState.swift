//
//  AppState.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

@Observable
final class AppState {
    let git = GitService()
    let watcher = FileWatcher()

    var repositories: [GitRepository] = []
    var selectedRepository: GitRepository?
    var selectedCommit: GitCommit?
    var selectedFileChange: GitFileChange?

    var commits: [GitCommit] = []
    var fileChanges: [GitFileChange] = []
    var branches: [GitBranch] = []
    var stashes: [GitStashEntry] = []
    var currentDiffLines: [DiffLine] = []
    var currentDiffFile: DiffFile?
    /// Line-level selection keyed by hunk index. Values are the indices of
    /// `+` / `-` lines within that hunk's `lines` array. A hunk with every
    /// modifiable line selected behaves identically to whole-hunk selection.
    var selectedLines: [Int: Set<Int>] = [:]
    var commitDiffLines: [DiffLine] = []
    var currentBlameLines: [BlameLine] = []
    var changesViewMode: ChangesViewMode = .diff
    var operationState: RepoOperationState = .idle
    var selectedBranchToMerge: String = ""
    var selectedBranchToRebase: String = ""

    enum ChangesViewMode: String, CaseIterable {
        case diff = "Diff"
        case blame = "Blame"
    }

    var isLoading = false
    var operationInProgress = false
    var errorMessage: String?
    var successMessage: String?

    var searchText: String = ""
    var currentTab: DetailTab = .changes

    /// Set when a push is requested on a branch with no upstream; drives the
    /// "set upstream and push" confirmation.
    var pendingUpstreamPush: PendingUpstreamPush?

    struct PendingUpstreamPush: Equatable, Sendable {
        let remote: String
        let branch: String
    }

    // Initialized in init() because @Observable breaks lazy
    private(set) var coordinator: GitCoordinator!

    enum DetailTab: String, CaseIterable {
        case changes = "Changes"
        case history = "History"
        case branches = "Branches"
        case stashes = "Stashes"
    }

    @MainActor init() {
        coordinator = GitCoordinator(state: self)
    }

    // MARK: - Repository path

    var currentRepoPath: String? {
        selectedRepository?.path
    }

    // MARK: - Search filtering

    /// The toolbar search field filters the active tab's list. An empty query
    /// passes everything through. Matching is case- and diacritic-insensitive.
    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredFileChanges: [GitFileChange] {
        let query = searchQuery
        guard !query.isEmpty else { return fileChanges }
        return fileChanges.filter { $0.path.localizedStandardContains(query) }
    }

    var filteredCommits: [GitCommit] {
        let query = searchQuery
        guard !query.isEmpty else { return commits }
        return commits.filter {
            $0.message.localizedStandardContains(query)
                || $0.author.localizedStandardContains(query)
                || $0.shortID.localizedStandardContains(query)
                || $0.id.lowercased().hasPrefix(query.lowercased())
        }
    }

    var filteredBranches: [GitBranch] {
        let query = searchQuery
        guard !query.isEmpty else { return branches }
        return branches.filter { $0.name.localizedStandardContains(query) }
    }

    var filteredStashes: [GitStashEntry] {
        let query = searchQuery
        guard !query.isEmpty else { return stashes }
        return stashes.filter { $0.message.localizedStandardContains(query) }
    }

    // MARK: - Setup file watcher

    func setupWatcher() {
        watcher.onChange = { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.refresh() }
        }
    }

}
