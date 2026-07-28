//
//  ConflictParserTests.swift
//  MapleTests
//
//  Covers ConflictParser.parse - the pure classifier that tags each line
//  of a conflicted file as ours / base / theirs / marker / normal so the
//  ConflictView can render and let the user pick a side. Mis-tagging a
//  line hands the user the wrong resolution, so every marker transition
//  is pinned here.
//

import Testing
@testable import Maple

struct ConflictParserTests {

    // MARK: - Helpers

    private func sides(_ source: String) -> [ConflictSide] {
        ConflictParser.parse(source).map(\.side)
    }

    // MARK: - No markers

    @Test func plainTextIsAllNormal() {
        let lines = ConflictParser.parse("one\ntwo\nthree")
        #expect(lines.count == 3)
        #expect(lines.allSatisfy { $0.side == .normal })
        #expect(lines.map(\.content) == ["one", "two", "three"])
    }

    @Test func emptyStringIsASingleNormalLine() {
        // components(separatedBy:) on "" yields [""] - one empty line.
        let lines = ConflictParser.parse("")
        #expect(lines.count == 1)
        #expect(lines[0].side == .normal)
    }

    // MARK: - Two-way conflict

    @Test func twoWayConflictTagsEachRegion() {
        let source = """
        context above
        <<<<<<< HEAD
        our change
        =======
        their change
        >>>>>>> feature
        context below
        """

        #expect(sides(source) == [
            .normal,        // context above
            .markerOurs,    // <<<<<<<
            .ours,          // our change
            .markerDivider, // =======
            .theirs,        // their change
            .markerTheirs,  // >>>>>>>
            .normal         // context below
        ])
    }

    @Test func multiLineRegionsKeepTheirSide() {
        let source = """
        <<<<<<< HEAD
        our line 1
        our line 2
        =======
        their line 1
        their line 2
        >>>>>>> branch
        """

        let lines = ConflictParser.parse(source)
        #expect(lines.filter { $0.side == .ours }.map(\.content) == ["our line 1", "our line 2"])
        #expect(lines.filter { $0.side == .theirs }.map(\.content) == ["their line 1", "their line 2"])
    }

    // MARK: - Three-way (diff3) conflict

    @Test func diff3ConflictTagsBaseRegion() {
        let source = """
        <<<<<<< HEAD
        ours
        ||||||| merged common ancestors
        base
        =======
        theirs
        >>>>>>> other
        """

        #expect(sides(source) == [
            .markerOurs,
            .ours,
            .markerBase,
            .base,
            .markerDivider,
            .theirs,
            .markerTheirs
        ])
    }

    // MARK: - Edge cases

    @Test func dividerOutsideConflictStaysNormal() {
        // A line of equals signs in ordinary content must not be mistaken for a
        // conflict divider: the parser only treats `=======` as a divider when
        // it is already inside a conflict region.
        let source = """
        title
        =======
        body
        """
        #expect(sides(source) == [.normal, .normal, .normal])
    }

    @Test func markerLinesPreserveTheirRawContent() {
        let lines = ConflictParser.parse("<<<<<<< HEAD\nx\n>>>>>>> topic")
        #expect(lines[0].content == "<<<<<<< HEAD")
        #expect(lines[2].content == ">>>>>>> topic")
    }
}
