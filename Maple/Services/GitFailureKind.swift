//
//  GitFailureKind.swift
//  Maple
//
//  Created by Pool Camacho on 7/28/26.
//

import Foundation

/// Classifies a failed git command into an actionable category by inspecting its
/// stderr. Pure and case-insensitive so it can be unit tested against real git
/// messages. `.unknown` means "show the raw error".
nonisolated enum GitFailureKind: Sendable, Equatable {
    case authenticationRequired
    case networkUnavailable
    case noUpstream
    case nonFastForward
    case mergeConflict
    case indexLocked
    case uncommittedChanges
    case nothingToCommit
    case unknown

    /// A friendly, actionable summary, or nil for `.unknown` (raw error is shown).
    var summary: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication failed. Check your credentials or SSH key for this remote."
        case .networkUnavailable:
            return "Could not reach the remote. Check your internet connection and try again."
        case .noUpstream:
            return "This branch has no upstream yet. Push it with an upstream set (git push -u) first."
        case .nonFastForward:
            return "Push rejected: the remote has commits you do not have locally. Pull or fetch, then push again."
        case .mergeConflict:
            return "There are merge conflicts to resolve before continuing."
        case .indexLocked:
            return "The repository is locked (.git/index.lock). Another git process may be running; remove the lock file if not."
        case .uncommittedChanges:
            return "You have local changes that would be overwritten. Commit or stash them first."
        case .nothingToCommit:
            return "Nothing to commit."
        case .unknown:
            return nil
        }
    }

    static func classify(command: String, message: String) -> GitFailureKind {
        let text = message.lowercased()

        func contains(_ needles: String...) -> Bool {
            needles.contains { text.contains($0) }
        }

        // Order matters: more specific signals are checked before broader ones.
        if contains("authentication failed", "could not read username", "could not read password",
                    "permission denied (publickey", "invalid username or password",
                    "terminal prompts disabled") {
            return .authenticationRequired
        }
        if contains("could not resolve host", "could not resolve hostname", "failed to connect",
                    "connection timed out", "network is unreachable", "connection refused",
                    "temporary failure in name resolution") {
            return .networkUnavailable
        }
        if contains("no upstream", "has no upstream branch") {
            return .noUpstream
        }
        if contains("non-fast-forward", "updates were rejected", "tip of your current branch is behind",
                    "fetch first") {
            return .nonFastForward
        }
        if contains("index.lock", "another git process seems to be running") {
            return .indexLocked
        }
        if contains("would be overwritten", "please commit your changes or stash them",
                    "cannot pull with rebase", "you have unstaged changes") {
            return .uncommittedChanges
        }
        if contains("automatic merge failed", "fix conflicts", "needs merge", "conflict, and must be resolved") {
            return .mergeConflict
        }
        if contains("nothing to commit", "no changes added to commit") {
            return .nothingToCommit
        }
        return .unknown
    }
}
