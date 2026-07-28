//
//  GitStatusIntegrationTests.swift
//  MapleTests
//
//  Hermetic integration tests: they create a real, throwaway git repo in a temp
//  directory and drive GitService against it. These validate that the real
//  `git status --porcelain=v2 -z` output actually matches StatusParser's
//  assumptions (field counts, header shape, rename encoding) end to end, which
//  pure fixtures alone cannot guarantee.
//

import Foundation
import Testing
@testable import Maple

struct GitStatusIntegrationTests {

    /// Spins up an isolated temp repo, runs `body`, then removes it.
    private func withTempRepo(_ body: (GitService, String) async throws -> Void) async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("maple-status-it-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let git = GitService()
        _ = try await git.run(["init"], in: dir.path)
        _ = try await git.run(["config", "user.email", "test@maple.local"], in: dir.path)
        _ = try await git.run(["config", "user.name", "Maple Test"], in: dir.path)

        try await body(git, dir.path)
    }

    private func write(_ contents: String, to name: String, in dir: String) throws {
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
    }

    @Test func reportsUntrackedStagedAndAdversarialPaths() async throws {
        try await withTempRepo { git, dir in
            try write("x", to: "a.txt", in: dir)
            try write("y", to: "my file.txt", in: dir)      // space in name
            try write("z", to: "café.txt", in: dir)          // unicode
            _ = try await git.run(["add", "my file.txt"], in: dir)

            let changes = try await git.status(in: dir)
            let byPath = Dictionary(grouping: changes, by: \.path).mapValues { $0.first }

            #expect(byPath["my file.txt"]??.isStaged == true)
            #expect(byPath["my file.txt"]??.status == .added)
            #expect(byPath["a.txt"]??.status == .untracked)
            #expect(byPath["café.txt"]??.status == .untracked)
        }
    }

    @Test func reportsWorkingTreeModification() async throws {
        try await withTempRepo { git, dir in
            try write("hello\n", to: "tracked.txt", in: dir)
            _ = try await git.run(["add", "tracked.txt"], in: dir)
            _ = try await git.run(["commit", "-m", "init"], in: dir)

            try write("hello world\n", to: "tracked.txt", in: dir)

            let changes = try await git.status(in: dir)
            #expect(changes.contains { $0.path == "tracked.txt" && !$0.isStaged && $0.status == .modified })
        }
    }

    @Test func reportsStagedRenameToPathWithSpace() async throws {
        try await withTempRepo { git, dir in
            try write("stable content\n", to: "tracked.txt", in: dir)
            _ = try await git.run(["add", "tracked.txt"], in: dir)
            _ = try await git.run(["commit", "-m", "init"], in: dir)

            _ = try await git.run(["mv", "tracked.txt", "renamed name.txt"], in: dir)

            let changes = try await git.status(in: dir)
            #expect(changes.contains { $0.path == "renamed name.txt" && $0.status == .renamed && $0.isStaged })
        }
    }
}
