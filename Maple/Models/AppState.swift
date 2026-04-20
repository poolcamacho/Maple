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
    var selectedHunks: Set<Int> = []
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

    // MARK: - Setup file watcher

    func setupWatcher() {
        watcher.onChange = { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.refresh() }
        }
    }

}
