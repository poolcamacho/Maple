//
//  GitUpstreamIntegrationTests.swift
//  MapleTests
//
//  Hermetic coverage for upstream detection and `push -u`, using a real bare
//  repo as the remote. Backs the "set upstream and push" flow that replaces the
//  raw "has no upstream branch" failure.
//

import Foundation
import Testing
@testable import Maple

struct GitUpstreamIntegrationTests {

    @Test func detectsMissingUpstreamThenSetsItOnPush() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("maple-up-\(UUID().uuidString)")
        let bare = root.appendingPathComponent("remote.git")
        let work = root.appendingPathComponent("work")
        try fm.createDirectory(at: bare, withIntermediateDirectories: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let git = GitService()
        _ = try await git.run(["init", "--bare"], in: bare.path)
        _ = try await git.run(["init"], in: work.path)
        _ = try await git.run(["config", "user.email", "test@maple.local"], in: work.path)
        _ = try await git.run(["config", "user.name", "Maple Test"], in: work.path)
        _ = try await git.run(["remote", "add", "origin", bare.path], in: work.path)
        try Data("hi\n".utf8).write(to: work.appendingPathComponent("f.txt"))
        _ = try await git.run(["add", "f.txt"], in: work.path)
        _ = try await git.run(["commit", "-m", "init"], in: work.path)

        // Before pushing: no upstream, exactly one remote named origin.
        let hasUpstreamBefore = await git.upstreamBranch(in: work.path)
        #expect(hasUpstreamBefore == nil)
        #expect(await git.remotes(in: work.path) == ["origin"])

        let branch = try await git.currentBranch(in: work.path)
        _ = try await git.push(remote: "origin", branch: branch, setUpstream: true, in: work.path)

        // After push -u: the branch tracks origin/<branch>.
        let upstreamAfter = await git.upstreamBranch(in: work.path)
        #expect(upstreamAfter == "origin/\(branch)")
    }
}
