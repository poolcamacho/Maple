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
}
