//
//  GitMergeRebase.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

extension GitService {

    // MARK: - Merge

    /// Returns the merge output. If the merge had conflicts, git still exits non-zero
    /// (code 1), so we surface that as a thrown error; the caller is responsible for
    /// inspecting the repo state to know whether conflicts were created.
    @discardableResult
    func merge(branch: String, in directory: String) async throws -> String {
        let output = try await run(["merge", "--no-edit", branch], in: directory)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func mergeAbort(in directory: String) async throws {
        _ = try await run(["merge", "--abort"], in: directory)
    }

    /// Finalize a merge after the user has resolved and staged all conflicts.
    func mergeContinue(in directory: String) async throws {
        _ = try await run(["commit", "--no-edit"], in: directory)
    }

    // MARK: - Rebase

    @discardableResult
    func rebase(onto branch: String, in directory: String) async throws -> String {
        let output = try await run(["rebase", branch], in: directory)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func rebaseAbort(in directory: String) async throws {
        _ = try await run(["rebase", "--abort"], in: directory)
    }

    func rebaseContinue(in directory: String) async throws {
        // `-c core.editor=true` short-circuits the editor so git doesn't wait on a UI
        _ = try await run(["-c", "core.editor=true", "rebase", "--continue"], in: directory)
    }

    func rebaseSkip(in directory: String) async throws {
        _ = try await run(["rebase", "--skip"], in: directory)
    }

    // MARK: - Conflict resolution helpers

    /// Use "ours" version of the file (current branch) for conflict resolution.
    func checkoutOurs(file: String, in directory: String) async throws {
        _ = try await run(["checkout", "--ours", "--", file], in: directory)
        _ = try await run(["add", "--", file], in: directory)
    }

    /// Use "theirs" version of the file (incoming branch) for conflict resolution.
    func checkoutTheirs(file: String, in directory: String) async throws {
        _ = try await run(["checkout", "--theirs", "--", file], in: directory)
        _ = try await run(["add", "--", file], in: directory)
    }

    /// Read raw file content (useful to display conflict markers verbatim).
    func readFileContent(_ filePath: String, in directory: String) -> String? {
        let fullPath = (directory as NSString).appendingPathComponent(filePath)
        return try? String(contentsOfFile: fullPath, encoding: .utf8)
    }

    // MARK: - Operation state detection

    /// Detects whether the repo is currently in the middle of merge/rebase/cherry-pick/revert.
    /// Uses filesystem markers in `.git/` because they're atomic and cheap to check.
    nonisolated func detectOperationState(in directory: String) -> RepoOperationState {
        let fm = FileManager.default
        let gitDir = (directory as NSString).appendingPathComponent(".git")

        // MERGE_HEAD => merging
        let mergeHead = (gitDir as NSString).appendingPathComponent("MERGE_HEAD")
        if fm.fileExists(atPath: mergeHead) {
            let head = (try? String(contentsOfFile: mergeHead, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let short = head.map { String($0.prefix(8)) }
            return .merging(head: short)
        }

        // rebase-merge or rebase-apply => rebasing
        let rebaseMerge = (gitDir as NSString).appendingPathComponent("rebase-merge")
        let rebaseApply = (gitDir as NSString).appendingPathComponent("rebase-apply")
        if fm.fileExists(atPath: rebaseMerge) || fm.fileExists(atPath: rebaseApply) {
            let headNameFile = (rebaseMerge as NSString).appendingPathComponent("head-name")
            let branch = (try? String(contentsOfFile: headNameFile, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "refs/heads/", with: "")
            return .rebasing(head: branch)
        }

        // CHERRY_PICK_HEAD => cherry-picking
        let cherry = (gitDir as NSString).appendingPathComponent("CHERRY_PICK_HEAD")
        if fm.fileExists(atPath: cherry) {
            return .cherryPicking
        }

        // REVERT_HEAD => reverting
        let revert = (gitDir as NSString).appendingPathComponent("REVERT_HEAD")
        if fm.fileExists(atPath: revert) {
            return .reverting
        }

        return .idle
    }
}
