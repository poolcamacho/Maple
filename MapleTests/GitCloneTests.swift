//
//  GitCloneTests.swift
//  MapleTests
//
//  Created by Pool Camacho on 7/28/26.
//
//  Covers clone URL -> folder-name derivation (pure) and an end-to-end clone of
//  a real local repository.
//

import Foundation
import Testing
@testable import Maple

struct GitCloneNameTests {

    @Test func derivesNameFromHTTPSURL() {
        #expect(GitService.repositoryName(fromCloneURL: "https://github.com/acme/repo.git") == "repo")
        #expect(GitService.repositoryName(fromCloneURL: "https://github.com/acme/repo") == "repo")
    }

    @Test func derivesNameFromSSHURL() {
        #expect(GitService.repositoryName(fromCloneURL: "git@github.com:acme/repo.git") == "repo")
    }

    @Test func stripsTrailingSlashAndDotGit() {
        #expect(GitService.repositoryName(fromCloneURL: "https://github.com/acme/repo.git/") == "repo")
        #expect(GitService.repositoryName(fromCloneURL: "  https://github.com/acme/My-Repo.git  ") == "My-Repo")
    }

    @Test func fallsBackWhenEmpty() {
        #expect(GitService.repositoryName(fromCloneURL: "") == "repository")
        #expect(GitService.repositoryName(fromCloneURL: "   ") == "repository")
    }
}

struct GitCloneIntegrationTests {

    @Test func clonesALocalRepository() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("maple-clone-\(UUID().uuidString)")
        let source = root.appendingPathComponent("source")
        let destinationParent = root.appendingPathComponent("dest")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try fm.createDirectory(at: destinationParent, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let git = GitService()
        _ = try await git.run(["init"], in: source.path)
        try? fm.removeItem(at: source.appendingPathComponent(".git/hooks"))
        _ = try await git.run(["config", "user.email", "test@maple.local"], in: source.path)
        _ = try await git.run(["config", "user.name", "Maple Test"], in: source.path)
        try Data("hello\n".utf8).write(to: source.appendingPathComponent("hello.txt"))
        _ = try await git.run(["add", "hello.txt"], in: source.path)
        _ = try await git.run(["commit", "-m", "seed"], in: source.path)

        let clonedPath = try await git.clone(url: source.path, into: destinationParent.path, name: "source")

        #expect(fm.fileExists(atPath: (clonedPath as NSString).appendingPathComponent("hello.txt")))
        #expect(await git.validateRepository(at: clonedPath) == nil)
    }
}
