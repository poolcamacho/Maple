//
//  DiffParserTests.swift
//  MapleTests
//
//  Covers DiffParser.parseFiles - the pure parser that converts raw
//  `git diff` / `git show` output into structured DiffFile values.
//  These tests are the safety net that lets the GitBackend migration
//  swap the engine without silently breaking diff rendering.
//

import Testing
@testable import Maple

struct DiffParserTests {

    // MARK: - Fixtures

    private static let singleFileSingleHunk = """
    diff --git a/foo.swift b/foo.swift
    index 1234567..89abcde 100644
    --- a/foo.swift
    +++ b/foo.swift
    @@ -1,3 +1,4 @@
     one
    -two
    +TWO
    +new
     three
    """

    private static let singleFileMultiHunk = """
    diff --git a/foo.swift b/foo.swift
    index 1111111..2222222 100644
    --- a/foo.swift
    +++ b/foo.swift
    @@ -1,3 +1,3 @@
     a
    -b
    +B
     c
    @@ -10,3 +10,4 @@
     x
     y
    +Y2
     z
    """

    private static let multiFile = """
    diff --git a/a.txt b/a.txt
    index aaa..bbb 100644
    --- a/a.txt
    +++ b/a.txt
    @@ -1 +1 @@
    -old
    +new
    diff --git a/b.txt b/b.txt
    index ccc..ddd 100644
    --- a/b.txt
    +++ b/b.txt
    @@ -1 +1 @@
    -foo
    +bar
    """

    private static let newFile = """
    diff --git a/added.swift b/added.swift
    new file mode 100644
    index 0000000..abcdef0
    --- /dev/null
    +++ b/added.swift
    @@ -0,0 +1,2 @@
    +first
    +second
    """

    private static let deletedFile = """
    diff --git a/gone.swift b/gone.swift
    deleted file mode 100644
    index abcdef0..0000000
    --- a/gone.swift
    +++ /dev/null
    @@ -1,2 +0,0 @@
    -line one
    -line two
    """

    // MARK: - Tests

    @Test func parsesSingleFileSingleHunk() {
        let files = DiffParser.parseFiles(Self.singleFileSingleHunk)

        #expect(files.count == 1)
        let file = files[0]
        #expect(file.path == "foo.swift")
        #expect(file.hunks.count == 1)

        let hunk = file.hunks[0]
        #expect(hunk.oldStart == 1)
        #expect(hunk.oldCount == 3)
        #expect(hunk.newStart == 1)
        #expect(hunk.newCount == 4)
        #expect(hunk.lines.count == 5) // one, -two, +TWO, +new, three
        #expect(hunk.lines.filter { $0.type == .addition }.count == 2)
        #expect(hunk.lines.filter { $0.type == .deletion }.count == 1)
        #expect(hunk.lines.filter { $0.type == .context }.count == 2)
    }

    @Test func parsesMultipleHunksInOneFile() {
        let files = DiffParser.parseFiles(Self.singleFileMultiHunk)

        #expect(files.count == 1)
        #expect(files[0].hunks.count == 2)
        #expect(files[0].hunks[0].oldStart == 1)
        #expect(files[0].hunks[1].oldStart == 10)
    }

    @Test func parsesMultipleFiles() {
        let files = DiffParser.parseFiles(Self.multiFile)

        #expect(files.count == 2)
        #expect(files[0].path == "a.txt")
        #expect(files[1].path == "b.txt")
        #expect(files.allSatisfy { $0.hunks.count == 1 })
    }

    @Test func parsesNewFile() {
        let files = DiffParser.parseFiles(Self.newFile)

        #expect(files.count == 1)
        let file = files[0]
        #expect(file.path == "added.swift")
        #expect(file.hunks[0].oldStart == 0)
        #expect(file.hunks[0].oldCount == 0)
        #expect(file.hunks[0].lines.allSatisfy { $0.type == .addition })
    }

    @Test func parsesDeletedFile() {
        let files = DiffParser.parseFiles(Self.deletedFile)

        #expect(files.count == 1)
        let file = files[0]
        #expect(file.hunks[0].newStart == 0)
        #expect(file.hunks[0].newCount == 0)
        #expect(file.hunks[0].lines.allSatisfy { $0.type == .deletion })
    }

    @Test func parseFlatIsConsistentWithParseFiles() {
        let flat = DiffParser.parseFlat(Self.singleFileMultiHunk)
        let files = DiffParser.parseFiles(Self.singleFileMultiHunk)

        // Flat view == hunk headers + hunk lines for every file, in order.
        var expectedCount = 0
        for file in files {
            for hunk in file.hunks {
                expectedCount += 1 + hunk.lines.count // header + lines
            }
        }
        #expect(flat.count == expectedCount)

        let headerCount = flat.filter { $0.type == .header }.count
        #expect(headerCount == 2)
    }

    @Test func emptyInputProducesNoFiles() {
        let files = DiffParser.parseFiles("")
        #expect(files.isEmpty)
    }

    private static let binaryFile = """
    diff --git a/logo.png b/logo.png
    index 1234567..89abcde 100644
    Binary files a/logo.png and b/logo.png differ
    """

    @Test func detectsBinaryFile() {
        let files = DiffParser.parseFiles(Self.binaryFile)
        #expect(files.count == 1)
        #expect(files[0].isBinary)
        #expect(files[0].hunks.isEmpty)
    }

    @Test func textDiffIsNotMarkedBinary() {
        let files = DiffParser.parseFiles(Self.singleFileSingleHunk)
        #expect(files[0].isBinary == false)
    }
}
