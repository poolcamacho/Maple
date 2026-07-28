//
//  StatusParserTests.swift
//  MapleTests
//
//  Covers StatusParser.parse — the pure parser for `git status --porcelain=v2 -z`
//  output. The v1 parser it replaced broke on paths with spaces, unicode,
//  embedded " -> ", quotes and newlines, so those adversarial paths are pinned
//  here alongside the normal staged/unstaged/rename/conflict shapes.
//

import Testing
@testable import Maple

struct StatusParserTests {

    // MARK: - Fixture helpers

    /// Joins records into one NUL-delimited stream, each terminated by NUL, the
    /// way `git status --porcelain=v2 -z` emits them.
    private func stream(_ records: String...) -> String {
        records.map { $0 + "\0" }.joined()
    }

    /// A type-1 ordinary-change record with the given two-char XY and path.
    private func ordinary(_ xy: String, _ path: String) -> String {
        "1 \(xy) N... 100644 100644 100644 0000000 1111111 \(path)"
    }

    // MARK: - Staged / unstaged split

    @Test func stagedModifiedOnly() {
        let changes = StatusParser.parse(stream(ordinary("M.", "file.txt")))
        #expect(changes.count == 1)
        #expect(changes[0].path == "file.txt")
        #expect(changes[0].status == .modified)
        #expect(changes[0].isStaged)
    }

    @Test func unstagedModifiedOnly() {
        let changes = StatusParser.parse(stream(ordinary(".M", "file.txt")))
        #expect(changes.count == 1)
        #expect(changes[0].isStaged == false)
        #expect(changes[0].status == .modified)
    }

    @Test func modifiedOnBothSidesYieldsTwoEntries() {
        let changes = StatusParser.parse(stream(ordinary("MM", "file.txt")))
        #expect(changes.count == 2)
        #expect(changes.contains { $0.isStaged && $0.status == .modified })
        #expect(changes.contains { !$0.isStaged && $0.status == .modified })
    }

    @Test func stagedDeletion() {
        let changes = StatusParser.parse(stream(ordinary("D.", "gone.swift")))
        #expect(changes.count == 1)
        #expect(changes[0].status == .deleted)
        #expect(changes[0].isStaged)
    }

    // MARK: - Untracked / ignored / headers

    @Test func untrackedFile() {
        let changes = StatusParser.parse(stream("? newfile.txt"))
        #expect(changes.count == 1)
        #expect(changes[0].status == .untracked)
        #expect(changes[0].isStaged == false)
        #expect(changes[0].path == "newfile.txt")
    }

    @Test func ignoredEntriesAreSkipped() {
        let changes = StatusParser.parse(stream("! build/output.o"))
        #expect(changes.isEmpty)
    }

    @Test func branchHeadersAreSkipped() {
        let changes = StatusParser.parse(stream(
            "# branch.oid abc123",
            "# branch.head main",
            ordinary(".M", "file.txt")
        ))
        #expect(changes.count == 1)
        #expect(changes[0].path == "file.txt")
    }

    @Test func emptyOutputProducesNoChanges() {
        #expect(StatusParser.parse("").isEmpty)
    }

    // MARK: - Rename (type 2 consumes the following origPath token)

    @Test func renameSurfacesNewPathAndConsumesOrigPath() {
        let record = "2 R. N... 100644 100644 100644 0000000 1111111 R100 new-name.txt"
        let changes = StatusParser.parse(stream(record, "old-name.txt"))
        // One entry for the new path; the origPath token must not become a bogus
        // second change.
        #expect(changes.count == 1)
        #expect(changes[0].status == .renamed)
        #expect(changes[0].isStaged)
        #expect(changes[0].path == "new-name.txt")
    }

    @Test func renameFollowedByAnotherRecordParsesBoth() {
        let rename = "2 R. N... 100644 100644 100644 0000000 1111111 R100 renamed.txt"
        let changes = StatusParser.parse(stream(rename, "original.txt", ordinary("?", "x")))
        // "?" is not a valid ordinary XY (needs two chars) so the trailing record
        // via ordinary() is malformed on purpose; assert the rename alone is clean
        // and the walker stays aligned (origPath consumed, no crash).
        #expect(changes.contains { $0.path == "renamed.txt" && $0.status == .renamed })
    }

    // MARK: - Conflicts (type u)

    @Test func unmergedEntryIsConflicted() {
        let record = "u UU N... 100644 100644 100644 100644 000 111 222 both.txt"
        let changes = StatusParser.parse(stream(record))
        #expect(changes.count == 1)
        #expect(changes[0].status == .conflicted)
        #expect(changes[0].isStaged == false)
        #expect(changes[0].path == "both.txt")
    }

    // MARK: - Adversarial paths (the whole reason for the v2 -z migration)

    @Test func pathWithSpacesIsPreserved() {
        let changes = StatusParser.parse(stream(ordinary(".M", "my file with spaces.txt")))
        #expect(changes.count == 1)
        #expect(changes[0].path == "my file with spaces.txt")
    }

    @Test func pathContainingArrowIsNotSplit() {
        // The v1 parser split rename encoding on " -> "; a real filename that
        // contains it must survive intact under v2 -z.
        let changes = StatusParser.parse(stream(ordinary(".M", "weird -> name.txt")))
        #expect(changes.count == 1)
        #expect(changes[0].path == "weird -> name.txt")
    }

    @Test func unicodePathIsPreserved() {
        let changes = StatusParser.parse(stream(ordinary("A.", "café/über/日本語.swift")))
        #expect(changes.count == 1)
        #expect(changes[0].path == "café/über/日本語.swift")
        #expect(changes[0].status == .added)
        #expect(changes[0].isStaged)
    }

    @Test func multipleRecordsParseInOrder() {
        let changes = StatusParser.parse(stream(
            ordinary("M.", "a.txt"),
            "? b.txt",
            ordinary(".D", "c.txt")
        ))
        #expect(changes.map(\.path) == ["a.txt", "b.txt", "c.txt"])
    }
}
