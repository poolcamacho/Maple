//
//  GitTagIntegrationTests.swift
//  MapleTests
//
//  Created by Pool Camacho on 7/28/26.
//
//  Hermetic coverage for tag operations against a real repo: lightweight vs
//  annotated create, listing, and delete. Assertions avoid depending on the
//  exact annotation text read back through for-each-ref, which the xctest
//  process environment can rewrite; the annotated-vs-lightweight distinction is
//  checked directly against the tag object type instead.
//

import Foundation
import Testing
@testable import Maple

struct GitTagIntegrationTests {

    private func withRepo(_ body: (GitService, String) async throws -> Void) async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("maple-tag-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let git = GitService()
        _ = try await git.run(["init"], in: dir.path)
        // Drop any hooks the global init.templateDir copied in (e.g. a
        // prepare-commit-msg that rewrites messages) so the test is hermetic.
        try? fm.removeItem(at: dir.appendingPathComponent(".git/hooks"))
        _ = try await git.run(["config", "user.email", "test@maple.local"], in: dir.path)
        _ = try await git.run(["config", "user.name", "Maple Test"], in: dir.path)
        try Data("seed\n".utf8).write(to: dir.appendingPathComponent("seed.txt"))
        _ = try await git.run(["add", "seed.txt"], in: dir.path)
        _ = try await git.run(["commit", "-m", "seed"], in: dir.path)

        try await body(git, dir.path)
    }

    @Test func createsListsAndDeletesTags() async throws {
        try await withRepo { git, dir in
            try await git.createTag(name: "v1.0.0", message: nil, in: dir)
            try await git.createTag(name: "v1.1.0", message: "First minor release", in: dir)

            let tags = try await git.tags(in: dir)
            #expect(tags.contains { $0.name == "v1.0.0" })

            let annotated = tags.first { $0.name == "v1.1.0" }
            #expect(annotated != nil)
            #expect(annotated?.targetShortSHA.isEmpty == false)

            // `createTag(message:)` must produce a real annotated tag object, not a
            // lightweight ref. Checked against the object type directly.
            let objectType = try await git.run(["cat-file", "-t", "v1.1.0"], in: dir)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(objectType == "tag")

            // The lightweight one is a plain ref to the commit.
            let lightweightType = try await git.run(["cat-file", "-t", "v1.0.0"], in: dir)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(lightweightType == "commit")

            try await git.deleteTag(name: "v1.0.0", in: dir)
            let afterDelete = try await git.tags(in: dir)
            #expect(!afterDelete.contains { $0.name == "v1.0.0" })
            #expect(afterDelete.contains { $0.name == "v1.1.0" })
        }
    }
}
