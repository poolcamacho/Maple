//
//  GitRunIntegrationTests.swift
//  MapleTests
//
//  Hermetic coverage for GitService.run's stdin path, which interactive staging
//  relies on (piping patches to `git apply --cached`). Guards the ordering fix
//  that drains stdout/stderr before feeding stdin so a large payload can't
//  deadlock against a full pipe buffer.
//

import Foundation
import Testing
@testable import Maple

struct GitRunIntegrationTests {

    private func withTempRepo(_ body: (GitService, String) async throws -> Void) async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("maple-run-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let git = GitService()
        _ = try await git.run(["init"], in: dir.path)
        try await body(git, dir.path)
    }

    /// stdin content must be delivered verbatim: the blob hash of "hello\n" is a
    /// fixed, version-independent SHA-1, so a correct hash proves the bytes
    /// reached git intact.
    @Test func stdinIsDeliveredVerbatim() async throws {
        try await withTempRepo { git, dir in
            let hash = try await git.run(["hash-object", "--stdin"], in: dir, stdin: "hello\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(hash == "ce013625030ba8dba906f756967f9e9ca394464a")
        }
    }

    /// A payload far larger than the ~64KB pipe buffer must still complete rather
    /// than deadlock. Before the fix this could hang until the command timed out.
    @Test func largeStdinCompletes() async throws {
        try await withTempRepo { git, dir in
            let big = String(repeating: "the quick brown fox\n", count: 40_000) // ~800KB
            let hash = try await git.run(["hash-object", "--stdin"], in: dir, stdin: big)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(hash.count == 40)
            #expect(hash.allSatisfy { $0.isHexDigit })
        }
    }
}
