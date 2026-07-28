//
//  AppStateSearchTests.swift
//  MapleTests
//
//  Covers AppState's search-filtering computed properties, which back the
//  toolbar search field. An empty query must pass everything through; a
//  non-empty query filters case- and diacritic-insensitively per tab.
//

import Foundation
import Testing
@testable import Maple

@MainActor
struct AppStateSearchTests {

    private func makeState() -> AppState {
        let state = AppState()
        state.fileChanges = [
            GitFileChange(path: "Sources/App.swift", status: .modified, isStaged: false),
            GitFileChange(path: "README.md", status: .modified, isStaged: true),
            GitFileChange(path: "café/notes.txt", status: .untracked, isStaged: false)
        ]
        state.commits = [
            GitCommit(id: "aaaaaaa1", shortID: "aaaaaaa", message: "Fix login bug",
                      author: "Ana", date: Date(timeIntervalSince1970: 0), branch: nil, parents: []),
            GitCommit(id: "bbbbbbb2", shortID: "bbbbbbb", message: "Add search",
                      author: "Beto", date: Date(timeIntervalSince1970: 0), branch: nil, parents: [])
        ]
        state.branches = [
            GitBranch(name: "main", isRemote: false, isCurrent: true),
            GitBranch(name: "feature/search", isRemote: false, isCurrent: false),
            GitBranch(name: "origin/main", isRemote: true, isCurrent: false)
        ]
        state.stashes = [
            GitStashEntry(id: "stash@{0}", index: 0, message: "WIP refactor", relativeDate: "1h"),
            GitStashEntry(id: "stash@{1}", index: 1, message: "temp styling", relativeDate: "2h")
        ]
        return state
    }

    // MARK: - Empty query passes through

    @Test func emptyQueryReturnsEverything() {
        let state = makeState()
        state.searchText = "   "
        #expect(state.filteredFileChanges.count == 3)
        #expect(state.filteredCommits.count == 2)
        #expect(state.filteredBranches.count == 3)
        #expect(state.filteredStashes.count == 2)
    }

    // MARK: - Per-field matching

    @Test func filtersFileChangesByPath() {
        let state = makeState()
        state.searchText = "readme"
        #expect(state.filteredFileChanges.map(\.path) == ["README.md"])
    }

    @Test func filtersCommitsByMessageAuthorAndSha() {
        let state = makeState()

        state.searchText = "login"
        #expect(state.filteredCommits.map(\.message) == ["Fix login bug"])

        state.searchText = "beto"
        #expect(state.filteredCommits.map(\.author) == ["Beto"])

        state.searchText = "bbbbbbb2"
        #expect(state.filteredCommits.map(\.id) == ["bbbbbbb2"])
    }

    @Test func filtersBranchesByName() {
        let state = makeState()
        state.searchText = "search"
        #expect(state.filteredBranches.map(\.name) == ["feature/search"])
    }

    @Test func filtersStashesByMessage() {
        let state = makeState()
        state.searchText = "refactor"
        #expect(state.filteredStashes.map(\.message) == ["WIP refactor"])
    }

    // MARK: - Case / diacritic insensitivity

    @Test func matchingIsCaseAndDiacriticInsensitive() {
        let state = makeState()
        state.searchText = "CAFE"
        #expect(state.filteredFileChanges.map(\.path) == ["café/notes.txt"])
    }

    @Test func nonMatchingQueryReturnsEmpty() {
        let state = makeState()
        state.searchText = "zzzzz-nothing"
        #expect(state.filteredFileChanges.isEmpty)
        #expect(state.filteredCommits.isEmpty)
        #expect(state.filteredBranches.isEmpty)
        #expect(state.filteredStashes.isEmpty)
    }
}
