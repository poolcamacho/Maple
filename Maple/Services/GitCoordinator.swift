//
//  GitCoordinator.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

@MainActor
final class GitCoordinator {
    private let state: AppState
    private var git: GitService { state.git }

    init(state: AppState) {
        self.state = state
    }

    // MARK: - Operation helpers

    enum RefreshStrategy {
        case load
        case refresh
        case none
    }

    private func runOperation(
        refresh strategy: RefreshStrategy = .load,
        success: String? = nil,
        errorHandler: ((Error) async -> Void)? = nil,
        work: (String) async throws -> Void
    ) async {
        guard let path = state.currentRepoPath else { return }
        state.operationInProgress = true
        state.errorMessage = nil
        state.successMessage = nil
        do {
            try await work(path)
            switch strategy {
            case .load: await loadRepositoryData()
            case .refresh: await refresh()
            case .none: break
            }
            if let success {
                state.successMessage = success
            }
        } catch {
            if let errorHandler {
                await errorHandler(error)
            } else {
                state.errorMessage = error.localizedDescription
            }
        }
        state.operationInProgress = false
    }

    private func runLightOperation(
        refresh strategy: RefreshStrategy = .refresh,
        success: String? = nil,
        work: (String) async throws -> Void
    ) async {
        guard let path = state.currentRepoPath else { return }
        do {
            try await work(path)
            switch strategy {
            case .load: await loadRepositoryData()
            case .refresh: await refresh()
            case .none: break
            }
            if let success {
                state.successMessage = success
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Open repository

    func openRepository(at path: String) async {
        let validationError = await git.validateRepository(at: path)
        if let validationError {
            state.errorMessage = validationError
            return
        }

        let name = await git.repositoryName(at: path)
        let branch: String
        do {
            branch = try await git.currentBranch(in: path)
        } catch {
            branch = "unknown"
        }

        let repo = GitRepository(name: name, path: path, currentBranch: branch)

        if !state.repositories.contains(where: { $0.path == path }) {
            state.repositories.append(repo)
        }
        state.selectedRepository = repo

        state.watcher.watch(directory: path)

        await loadRepositoryData()
    }

    // MARK: - Load all data for selected repo

    func loadRepositoryData() async {
        guard let path = state.currentRepoPath else { return }
        state.isLoading = true
        state.errorMessage = nil

        do {
            async let statusTask = git.status(in: path)
            async let logTask = git.log(in: path)
            async let branchTask = git.branches(in: path)
            async let currentBranchTask = git.currentBranch(in: path)
            async let stashTask = git.stashList(in: path)

            let (status, log, branchList, branch, stashList) = try await (
                statusTask, logTask, branchTask, currentBranchTask, stashTask
            )

            state.fileChanges = status
            state.commits = log
            state.branches = branchList
            state.stashes = stashList
            state.operationState = git.detectOperationState(in: path)

            if let index = state.repositories.firstIndex(where: { $0.path == path }) {
                state.repositories[index].currentBranch = branch
                state.selectedRepository = state.repositories[index]
            }

            state.selectedCommit = nil
            state.selectedFileChange = nil
            state.currentDiffLines = []
            state.currentDiffFile = nil
            state.selectedLines = [:]
            state.commitDiffLines = []
        } catch {
            state.errorMessage = error.localizedDescription
        }

        state.isLoading = false
    }

    // MARK: - Refresh (lightweight)

    func refresh() async {
        guard let path = state.currentRepoPath else { return }

        do {
            async let statusTask = git.status(in: path)
            async let branchTask = git.branches(in: path)
            async let currentBranchTask = git.currentBranch(in: path)
            async let stashTask = git.stashList(in: path)

            let (status, branchList, branch, stashList) = try await (
                statusTask, branchTask, currentBranchTask, stashTask
            )

            state.fileChanges = status
            state.branches = branchList
            state.stashes = stashList
            state.operationState = git.detectOperationState(in: path)

            if let index = state.repositories.firstIndex(where: { $0.path == path }) {
                state.repositories[index].currentBranch = branch
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load diffs

    func loadFileDiff() async {
        guard let path = state.currentRepoPath, let file = state.selectedFileChange else {
            state.currentDiffLines = []
            state.currentDiffFile = nil
            state.selectedLines = [:]
            return
        }

        state.selectedLines = [:]

        do {
            if file.status == .untracked {
                state.currentDiffLines = try await git.diffForUntrackedFile(file.path, in: path)
                state.currentDiffFile = nil
            } else {
                let diffFile = try await git.diffFile(for: file.path, staged: file.isStaged, in: path)
                state.currentDiffFile = diffFile
                state.currentDiffLines = diffFile?.flattened ?? []
            }
        } catch {
            state.currentDiffLines = []
            state.currentDiffFile = nil
        }
    }

    func loadBlame() async {
        guard let path = state.currentRepoPath, let file = state.selectedFileChange else {
            state.currentBlameLines = []
            return
        }

        // Untracked files have no history to blame.
        if file.status == .untracked {
            state.currentBlameLines = []
            return
        }

        do {
            state.currentBlameLines = try await git.blame(for: file.path, in: path)
        } catch {
            state.currentBlameLines = []
        }
    }

    func loadCommitDiff() async {
        guard let path = state.currentRepoPath, let commit = state.selectedCommit else {
            state.commitDiffLines = []
            return
        }

        do {
            state.commitDiffLines = try await git.diffForCommit(commit.id, in: path)
        } catch {
            state.commitDiffLines = []
        }
    }

    // MARK: - Stage / Unstage

    func stageFile(_ file: GitFileChange) async {
        await runLightOperation { path in
            try await git.stage(file: file.path, in: path)
        }
    }

    func unstageFile(_ file: GitFileChange) async {
        await runLightOperation { path in
            try await git.unstage(file: file.path, in: path)
        }
    }

    func stageAllFiles() async {
        await runLightOperation { path in
            try await git.stageAll(in: path)
        }
    }

    func unstageAllFiles() async {
        await runLightOperation { path in
            try await git.unstageAll(in: path)
        }
    }

    // MARK: - Hunk / line staging

    /// Stages the selected `+` / `-` lines of the currently viewed (unstaged)
    /// file by piping a reconstructed patch to `git apply --cached`. When an
    /// entire hunk's worth of lines is selected the result is identical to the
    /// whole-hunk patch.
    func stageSelectedLines() async {
        guard let file = state.currentDiffFile,
              !state.selectedLines.isEmpty else { return }
        let patch = file.patchText(forLines: state.selectedLines)
        guard !patch.isEmpty else { return }

        await runLightOperation { path in
            try await git.applyPatch(patch, cached: true, in: path)
        }
        await loadFileDiff()
    }

    /// Unstages the selected `+` / `-` lines of the currently viewed (staged)
    /// file by piping the reverse patch to `git apply --cached --reverse`.
    func unstageSelectedLines() async {
        guard let file = state.currentDiffFile,
              !state.selectedLines.isEmpty else { return }
        let patch = file.patchText(forLines: state.selectedLines)
        guard !patch.isEmpty else { return }

        await runLightOperation { path in
            try await git.applyPatch(patch, cached: true, reverse: true, in: path)
        }
        await loadFileDiff()
    }

    // MARK: - Commit

    func performCommit(message: String, amend: Bool = false) async {
        await runOperation(refresh: .load, success: "Committed successfully") { path in
            try await git.commit(message: message, amend: amend, in: path)
        }
    }

    // MARK: - Push / Pull / Fetch

    func performPush() async {
        var successOverride: String?
        await runOperation(refresh: .refresh) { path in
            let output = try await git.push(in: path)
            successOverride = output.isEmpty ? "Pushed successfully" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func performPull() async {
        var successOverride: String?
        await runOperation(refresh: .load) { path in
            let output = try await git.pull(in: path)
            successOverride = output.isEmpty ? "Pulled successfully" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func performFetch() async {
        await runOperation(refresh: .refresh, success: "Fetched successfully") { path in
            _ = try await git.fetch(in: path)
        }
    }

    // MARK: - Branch operations

    func checkoutBranch(_ branch: GitBranch) async {
        await runOperation(refresh: .load) { path in
            if branch.isRemote {
                try await git.checkoutRemoteBranch(branch.name, in: path)
            } else {
                try await git.checkout(branch: branch.name, in: path)
            }
        }
    }

    func createNewBranch(name: String) async {
        guard !name.isEmpty else { return }
        await runOperation(refresh: .load, success: "Branch '\(name)' created") { path in
            try await git.createBranch(name: name, in: path)
        }
    }

    // MARK: - Merge / Rebase

    func performMerge(branch: String) async {
        guard !branch.isEmpty else { return }
        var successOverride: String?
        await runOperation(
            refresh: .load,
            errorHandler: { [weak self] error in
                guard let self else { return }
                // git merge returns non-zero on conflict — refresh state so user sees conflicts
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "Merge has conflicts. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            let output = try await git.merge(branch: branch, in: path)
            successOverride = output.isEmpty ? "Merged \(branch)" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func abortMerge() async {
        await runOperation(refresh: .load, success: "Merge aborted") { path in
            try await git.mergeAbort(in: path)
        }
    }

    func continueMerge() async {
        await runOperation(refresh: .load, success: "Merge completed") { path in
            try await git.mergeContinue(in: path)
        }
    }

    func performRebase(onto branch: String) async {
        guard !branch.isEmpty else { return }
        var successOverride: String?
        await runOperation(
            refresh: .load,
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "Rebase has conflicts. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            let output = try await git.rebase(onto: branch, in: path)
            successOverride = output.isEmpty ? "Rebased onto \(branch)" : output
        }
        if let successOverride {
            state.successMessage = successOverride
        }
    }

    func abortRebase() async {
        await runOperation(refresh: .load, success: "Rebase aborted") { path in
            try await git.rebaseAbort(in: path)
        }
    }

    func continueRebase() async {
        await runOperation(
            refresh: .load,
            success: "Rebase continued",
            errorHandler: { [weak self] error in
                guard let self else { return }
                await self.loadRepositoryData()
                if self.state.operationState.isInProgress {
                    self.state.errorMessage = "More conflicts remain. Resolve them and click Continue."
                } else {
                    self.state.errorMessage = error.localizedDescription
                }
            }
        ) { path in
            try await git.rebaseContinue(in: path)
        }
    }

    func skipRebase() async {
        await runOperation(refresh: .load) { path in
            try await git.rebaseSkip(in: path)
        }
    }

    func useOurs(file: GitFileChange) async {
        await runLightOperation { path in
            try await git.checkoutOurs(file: file.path, in: path)
        }
    }

    func useTheirs(file: GitFileChange) async {
        await runLightOperation { path in
            try await git.checkoutTheirs(file: file.path, in: path)
        }
    }

    func deleteLocalBranch(_ branch: GitBranch) async {
        await runLightOperation { path in
            try await git.deleteBranch(name: branch.name, in: path)
        }
    }

    // MARK: - Stash operations

    func performStashSave(message: String?) async {
        await runOperation(refresh: .load, success: "Changes stashed") { path in
            try await git.stashSave(message: message, in: path)
        }
    }

    func performStashPop(index: Int = 0) async {
        await runLightOperation(refresh: .load, success: "Stash popped") { path in
            try await git.stashPop(index: index, in: path)
        }
    }

    func performStashApply(index: Int = 0) async {
        await runLightOperation(refresh: .load) { path in
            try await git.stashApply(index: index, in: path)
        }
    }

    func performStashDrop(index: Int) async {
        await runLightOperation(refresh: .load) { path in
            try await git.stashDrop(index: index, in: path)
        }
    }
}
