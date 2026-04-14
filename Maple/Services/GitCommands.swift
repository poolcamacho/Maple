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
    func push(remote: String = "origin", branch: String? = nil, in directory: String) async throws -> String {
        var args = ["push", remote]
        if let branch {
            args.append(branch)
        }
        let output = try await run(args, in: directory, timeout: Self.networkTimeout)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
