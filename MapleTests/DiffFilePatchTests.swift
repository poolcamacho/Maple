//
//  DiffFilePatchTests.swift
//  MapleTests
//
//  Covers DiffFile.patchText(forHunkIndices:) and patchText(forLines:) -
//  the patch reconstructors that power interactive staging. Wrong
//  output here corrupts the index, so these tests are table-driven
//  over every selection permutation that matters.
//

import Testing
@testable import Maple

struct DiffFilePatchTests {

    // MARK: - Fixture
    //
    // One file, one hunk:
    //   @@ -1,3 +1,4 @@
    //    keep1
    //   -old
    //   +new1
    //   +new2
    //    keep2
    //
    // hunk.lines indices:
    //   0: context  keep1
    //   1: deletion old
    //   2: addition new1
    //   3: addition new2
    //   4: context  keep2

    private static let fixture = """
    diff --git a/file.txt b/file.txt
    index 111..222 100644
    --- a/file.txt
    +++ b/file.txt
    @@ -1,3 +1,4 @@
     keep1
    -old
    +new1
    +new2
     keep2
    """

    private static func parseFixture() -> DiffFile {
        guard let file = DiffParser.parseFiles(fixture).first else {
            Issue.record("Fixture failed to parse")
            return DiffFile(path: nil, preamble: [], hunks: [])
        }
        return file
    }

    private static let preamble = """
    diff --git a/file.txt b/file.txt
    index 111..222 100644
    --- a/file.txt
    +++ b/file.txt
    """

    // MARK: - Whole-hunk selection

    @Test func emptyHunkSelectionReturnsEmptyString() {
        let file = Self.parseFixture()
        #expect(file.patchText(forHunkIndices: []).isEmpty)
    }

    @Test func singleWholeHunkRebuildsOriginal() {
        let file = Self.parseFixture()
        let expected = """
        \(Self.preamble)
        @@ -1,3 +1,4 @@
         keep1
        -old
        +new1
        +new2
         keep2

        """
        #expect(file.patchText(forHunkIndices: [0]) == expected)
    }

    // MARK: - Line-level selection

    @Test func emptyLineSelectionReturnsEmptyString() {
        let file = Self.parseFixture()
        #expect(file.patchText(forLines: [:]).isEmpty)
    }

    @Test func hunkWithEmptySelectionIsSkipped() {
        let file = Self.parseFixture()
        // Key exists but set empty - guard drops it before emitting anything.
        #expect(file.patchText(forLines: [0: []]).isEmpty)
    }

    @Test func hunkWithNoRealEditIsSkipped() {
        let file = Self.parseFixture()
        // Selecting a context line only (index 0) means hasRealEdit stays
        // false - no +/- survives - so the hunk contributes nothing.
        #expect(file.patchText(forLines: [0: [0]]).isEmpty)
    }

    @Test func selectOnlyDeletionDropsAdditions() {
        let file = Self.parseFixture()
        // Selecting index 1 (`-old`). Additions at 2 and 3 are dropped
        // (they're not in the old side, nor do we want them on the new side).
        // Header: old=3, new=2.
        let expected = """
        \(Self.preamble)
        @@ -1,3 +1,2 @@
         keep1
        -old
         keep2

        """
        #expect(file.patchText(forLines: [0: [1]]) == expected)
    }

    @Test func selectOnlyFirstAdditionDemotesDeletion() {
        let file = Self.parseFixture()
        // Selecting index 2 (`+new1`). Unselected deletion at 1 becomes
        // context; unselected addition at 3 is dropped.
        // Header: old=3, new=4.
        let expected = """
        \(Self.preamble)
        @@ -1,3 +1,4 @@
         keep1
         old
        +new1
         keep2

        """
        #expect(file.patchText(forLines: [0: [2]]) == expected)
    }

    @Test func selectAllModifiableMatchesWholeHunkPath() {
        let file = Self.parseFixture()
        // Selecting every +/- line index (1,2,3) via the line-level path
        // should produce a patch semantically identical to asking for
        // the whole hunk via the hunk-index path. Recomputed counts
        // match the original header's because every modifiable line is
        // emitted with its original prefix.
        let byLine = file.patchText(forLines: [0: [1, 2, 3]])
        let byHunk = file.patchText(forHunkIndices: [0])
        #expect(byLine == byHunk)
    }

    @Test func unselectedDeletionBecomesContextInOutput() {
        let file = Self.parseFixture()
        let output = file.patchText(forLines: [0: [2]]) // only +new1
        // The ` old` line (space-prefixed) must appear; `-old` must not.
        #expect(output.contains("\n old\n"))
        #expect(!output.contains("\n-old\n"))
    }

    @Test func unselectedAdditionIsAbsent() {
        let file = Self.parseFixture()
        let output = file.patchText(forLines: [0: [2]]) // only +new1
        #expect(!output.contains("new2"))
    }
}
