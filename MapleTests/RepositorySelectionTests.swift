//
//  RepositorySelectionTests.swift
//  MapleTests
//
//  Regression coverage for the repo-switching bug: selecting a repository must
//  load that repository's own branches, and must never leave a previously
//  selected repository's data on screen. Drives the real GitCoordinator against
//  two hermetic temp repos with distinctly named branches.
//

import Foundation
import Testing
@testable import Maple

@MainActor
struct RepositorySelectionTests {

    /// Creates a temp repo with one commit and a local branch named `branch`.
    /// Returns its path. Caller is responsible for cleanup via `cleanup`.
    private func makeRepo(branch: String) async throws -> String {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("maple-sel-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let git = GitService()
        _ = try await git.run(["init"], in: dir.path)
        _ = try await git.run(["config", "user.email", "test@maple.local"], in: dir.path)
        _ = try await git.run(["config", "user.name", "Maple Test"], in: dir.path)
        try Data("seed\n".utf8).write(to: dir.appendingPathComponent("seed.txt"))
        _ = try await git.run(["add", "seed.txt"], in: dir.path)
        _ = try await git.run(["commit", "-m", "seed"], in: dir.path)
        _ = try await git.run(["branch", branch], in: dir.path)

        return dir.path
    }

    private func cleanup(_ paths: String...) {
        for path in paths { try? FileManager.default.removeItem(atPath: path) }
    }

    @Test func selectingARepositoryLoadsItsOwnBranchesWithoutBleed() async throws {
        let repoA = try await makeRepo(branch: "alpha-branch")
        let repoB = try await makeRepo(branch: "beta-branch")
        defer { cleanup(repoA, repoB) }

        let state = AppState()

        // Open A, then load it the way the sidebar selection onChange does.
        await state.coordinator.openRepository(at: repoA)
        await state.coordinator.selectRepository()
        #expect(state.branches.contains { $0.name == "alpha-branch" })

        // Open B: its branches replace A's, no bleed.
        await state.coordinator.openRepository(at: repoB)
        await state.coordinator.selectRepository()
        #expect(state.branches.contains { $0.name == "beta-branch" })
        #expect(!state.branches.contains { $0.name == "alpha-branch" })

        // The bug: click back to A. Selecting it must reload A's branches.
        state.selectedRepository = state.repositories.first { $0.path == repoA }
        await state.coordinator.selectRepository()
        #expect(state.branches.contains { $0.name == "alpha-branch" })
        #expect(!state.branches.contains { $0.name == "beta-branch" })

        state.watcher.stop()
    }
}
