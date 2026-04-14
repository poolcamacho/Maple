//
//  GitBranchOps.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

extension GitService {

    // MARK: - Checkout

    /// Switches to the specified branch.
    func checkout(branch: String, in directory: String) async throws {
        _ = try await run(["checkout", branch], in: directory)
    }

    // MARK: - Create Branch

    /// Creates a new branch, optionally from a given start point.
    /// - Parameters:
    ///   - name: The name for the new branch.
    ///   - startPoint: An optional commit, tag, or branch to start from.
    ///   - checkout: If `true` (default), checks out the new branch after creation.
    ///   - directory: The repository working directory.
    func createBranch(name: String, startPoint: String? = nil, checkout: Bool = true, in directory: String) async throws {
        if checkout {
            var args = ["checkout", "-b", name]
            if let startPoint {
                args.append(startPoint)
            }
            _ = try await run(args, in: directory)
        } else {
            var args = ["branch", name]
            if let startPoint {
                args.append(startPoint)
            }
            _ = try await run(args, in: directory)
        }
    }

    // MARK: - Delete Branch

    /// Deletes a local branch.
    /// - Parameters:
    ///   - name: The branch to delete.
    ///   - force: If `true`, uses `-D` (force delete) instead of `-d`.
    ///   - directory: The repository working directory.
    func deleteBranch(name: String, force: Bool = false, in directory: String) async throws {
        let flag = force ? "-D" : "-d"
        _ = try await run(["branch", flag, name], in: directory)
    }

    // MARK: - Checkout Remote Branch

    /// Checks out a remote branch by creating a local tracking branch.
    /// e.g. "origin/feat/foo" → `git checkout -b feat/foo origin/feat/foo`
    func checkoutRemoteBranch(_ remoteBranch: String, in directory: String) async throws {
        // Strip the remote prefix: "origin/feat/foo" → "feat/foo"
        let parts = remoteBranch.split(separator: "/", maxSplits: 1)
        let localName = parts.count > 1 ? String(parts[1]) : remoteBranch

        _ = try await run(["checkout", "-b", localName, remoteBranch], in: directory)
    }

    // MARK: - Rename Branch

    /// Renames a local branch.
    func renameBranch(oldName: String, newName: String, in directory: String) async throws {
        _ = try await run(["branch", "-m", oldName, newName], in: directory)
    }
}
