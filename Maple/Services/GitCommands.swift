//
//  GitCommands.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

extension GitService {

    private static let networkTimeout: TimeInterval = 60

    // MARK: - Commit

    func commit(message: String, amend: Bool = false, in directory: String) async throws {
        var args = ["commit", "-m", message]
        if amend {
            args.append("--amend")
        }
        _ = try await run(args, in: directory)
    }

    // MARK: - Push

    @discardableResult
    func push(
        remote: String = "origin",
        branch: String? = nil,
        setUpstream: Bool = false,
        in directory: String
    ) async throws -> String {
        var args = ["push"]
        if setUpstream {
            args.append("-u")
        }
        args.append(remote)
        if let branch {
            args.append(branch)
        }
        let output = try await run(args, in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The upstream (tracking) ref of the current branch, e.g. "origin/main", or
    /// nil if the branch has none.
    func upstreamBranch(in directory: String) async -> String? {
        let result = try? await run(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            in: directory
        )
        let trimmed = result?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    /// Configured remote names, in git's listing order.
    func remotes(in directory: String) async -> [String] {
        let output = (try? await run(["remote"], in: directory)) ?? ""
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Pull

    @discardableResult
    func pull(remote: String = "origin", branch: String? = nil, in directory: String) async throws -> String {
        var args = ["pull", remote]
        if let branch {
            args.append(branch)
        }
        let output = try await run(args, in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fetch

    @discardableResult
    func fetch(remote: String = "origin", in directory: String) async throws -> String {
        let output = try await run(["fetch", remote], in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Clone

    private static let cloneTimeout: TimeInterval = 600

    /// Clones `url` into `parentDirectory`/`name` and returns the resulting repo
    /// path. `parentDirectory` must already exist.
    func clone(url: String, into parentDirectory: String, name: String) async throws -> String {
        let destination = (parentDirectory as NSString).appendingPathComponent(name)
        _ = try await run(["clone", url, destination], in: parentDirectory, timeout: Self.cloneTimeout)
        return destination
    }

    /// Derives a folder name from a clone URL, e.g.
    /// `https://github.com/acme/repo.git` or `git@github.com:acme/repo.git` ->
    /// `repo`. Falls back to "repository" if nothing usable is found.
    nonisolated static func repositoryName(fromCloneURL url: String) -> String {
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed = String(trimmed.dropLast()) }
        if trimmed.hasSuffix(".git") { trimmed = String(trimmed.dropLast(4)) }
        while trimmed.hasSuffix("/") { trimmed = String(trimmed.dropLast()) }

        if let separator = trimmed.lastIndex(where: { $0 == "/" || $0 == ":" }) {
            trimmed = String(trimmed[trimmed.index(after: separator)...])
        }
        return trimmed.isEmpty ? "repository" : trimmed
    }
}
