//
//  GitRepositoryPathsTests.swift
//  MapleTests
//
//  Hermetic coverage for GitService.repositoryPaths, which the FileWatcher relies
//  on to follow refs and the index in worktrees and submodules. Validates against
//  a real normal repo and a real linked worktree, where the git dir and the
//  common dir diverge.
//

import Foundation
import Testing
@testable import Maple

struct GitRepositoryPathsTests {

    private func run(_ git: GitService, _ args: [String], in dir: String) async throws {
        _ = try await git.run(args, in: dir)
    }

    private func seedRepo(_ git: GitService, at dir: String) async throws {
        try await run(git, ["init"], in: dir)
        try await run(git, ["config", "user.email", "test@maple.local"], in: dir)
        try await run(git, ["config", "user.name", "Maple Test"], in: dir)
        try Data("seed\n".utf8).write(to: URL(fileURLWithPath: dir).appendingPathComponent("seed.txt"))
        try await run(git, ["add", "seed.txt"], in: dir)
        try await run(git, ["commit", "-m", "seed"], in: dir)
    }

    @Test func normalRepoHasMatchingGitAndCommonDirs() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("maple-paths-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let git = GitService()
        try await seedRepo(git, at: dir.path)

        let paths = await git.repositoryPaths(in: dir.path)
        #expect(paths != nil)
        // A normal repo has no linked worktree: git dir and common dir coincide.
        #expect(paths?.gitDir == paths?.commonDir)
        #expect(paths?.gitDir.hasSuffix("/.git") == true)
        #expect(paths?.workTree.isEmpty == false)
    }

    @Test func worktreeHasDivergentGitAndCommonDirs() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("maple-wt-\(UUID().uuidString)")
        let main = root.appendingPathComponent("main")
        let linked = root.appendingPathComponent("linked")
        try fm.createDirectory(at: main, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let git = GitService()
        try await seedRepo(git, at: main.path)
        try await run(git, ["worktree", "add", linked.path, "-b", "wt-branch"], in: main.path)

        let paths = await git.repositoryPaths(in: linked.path)
        #expect(paths != nil)
        // In a linked worktree the per-checkout git dir lives under
        // <main>/.git/worktrees/<name>, while refs stay in the shared common dir.
        #expect(paths?.gitDir != paths?.commonDir)
        #expect(paths?.gitDir.contains("/worktrees/") == true)
        #expect(paths?.commonDir.hasSuffix("/.git") == true)
        #expect(URL(fileURLWithPath: paths?.workTree ?? "").lastPathComponent == "linked")
    }
}
