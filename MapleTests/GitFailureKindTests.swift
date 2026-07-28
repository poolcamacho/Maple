//
//  GitFailureKindTests.swift
//  MapleTests
//
//  Covers GitFailureKind.classify, which turns raw git stderr into actionable
//  categories, and its wiring into GitError.errorDescription. Fixtures are real
//  git failure messages.
//

import Testing
@testable import Maple

struct GitFailureKindTests {

    @Test func detectsAuthenticationFailures() {
        #expect(GitFailureKind.classify(
            command: "push",
            message: "fatal: Authentication failed for 'https://github.com/acme/repo.git/'"
        ) == .authenticationRequired)

        #expect(GitFailureKind.classify(
            command: "fetch",
            message: "git@github.com: Permission denied (publickey).\nfatal: Could not read from remote repository."
        ) == .authenticationRequired)

        #expect(GitFailureKind.classify(
            command: "push",
            message: "fatal: could not read Username for 'https://github.com': terminal prompts disabled"
        ) == .authenticationRequired)
    }

    @Test func detectsNetworkFailures() {
        #expect(GitFailureKind.classify(
            command: "fetch",
            message: "fatal: unable to access 'https://github.com/acme/repo.git/': Could not resolve host: github.com"
        ) == .networkUnavailable)
    }

    @Test func detectsNoUpstream() {
        #expect(GitFailureKind.classify(
            command: "push",
            message: "fatal: The current branch feature/x has no upstream branch."
        ) == .noUpstream)
    }

    @Test func detectsNonFastForward() {
        #expect(GitFailureKind.classify(
            command: "push",
            message: " ! [rejected]        main -> main (non-fast-forward)\nerror: failed to push some refs"
        ) == .nonFastForward)
    }

    @Test func detectsIndexLock() {
        #expect(GitFailureKind.classify(
            command: "commit",
            message: "fatal: Unable to create '/repo/.git/index.lock': File exists.\nAnother git process seems to be running"
        ) == .indexLocked)
    }

    @Test func detectsUncommittedChanges() {
        #expect(GitFailureKind.classify(
            command: "checkout",
            message: "error: Your local changes to the following files would be overwritten by checkout:\n\tapp.swift"
        ) == .uncommittedChanges)
    }

    @Test func detectsMergeConflict() {
        #expect(GitFailureKind.classify(
            command: "merge",
            message: "Automatic merge failed; fix conflicts and then commit the result."
        ) == .mergeConflict)
    }

    @Test func detectsNothingToCommit() {
        #expect(GitFailureKind.classify(
            command: "commit",
            message: "nothing to commit, working tree clean"
        ) == .nothingToCommit)
    }

    @Test func unrecognizedMessageIsUnknownWithNoSummary() {
        let kind = GitFailureKind.classify(command: "status", message: "fatal: some novel failure")
        #expect(kind == .unknown)
        #expect(kind.summary == nil)
    }

    @Test func errorDescriptionUsesFriendlySummaryForKnownKinds() {
        let error = GitError.commandFailed(
            command: "push",
            exitCode: 128,
            message: "fatal: The current branch main has no upstream branch."
        )
        #expect(error.errorDescription == GitFailureKind.noUpstream.summary)
    }

    @Test func errorDescriptionFallsBackToRawForUnknown() {
        let error = GitError.commandFailed(command: "status", exitCode: 1, message: "fatal: weird thing")
        let description = error.errorDescription ?? ""
        #expect(description.contains("weird thing"))
        #expect(description.contains("git status failed (1)"))
    }
}
