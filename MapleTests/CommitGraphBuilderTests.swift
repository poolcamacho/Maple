//
//  CommitGraphBuilderTests.swift
//  MapleTests
//
//  Covers CommitGraphBuilder.build - the lane/edge layout engine behind the
//  History tab's commit graph. Lane assignment and parent-edge resolution are
//  easy to regress silently (the graph still draws, just wrong), so linear,
//  merge, and out-of-view-parent shapes are pinned here.
//

import Foundation
import Testing
@testable import Maple

struct CommitGraphBuilderTests {

    // MARK: - Helpers

    /// Commits are consumed newest-first, matching `git log` order.
    private func commit(_ id: String, parents: [String]) -> GitCommit {
        GitCommit(
            id: id,
            shortID: String(id.prefix(7)),
            message: "msg \(id)",
            author: "Tester",
            date: Date(timeIntervalSince1970: 0),
            branch: nil,
            parents: parents
        )
    }

    // MARK: - Empty

    @Test func emptyHistoryHasNoNodesAndOneLane() {
        let layout = CommitGraphBuilder.build(from: [])
        #expect(layout.nodes.isEmpty)
        #expect(layout.edges.isEmpty)
        // laneCount is clamped to at least 1 so the renderer always has a column.
        #expect(layout.laneCount == 1)
    }

    // MARK: - Linear history

    @Test func linearHistoryStaysInOneLane() {
        let layout = CommitGraphBuilder.build(from: [
            commit("c", parents: ["b"]),
            commit("b", parents: ["a"]),
            commit("a", parents: [])
        ])

        #expect(layout.nodes.count == 3)
        #expect(layout.laneCount == 1)
        #expect(layout.nodes.allSatisfy { $0.lane == 0 })
        #expect(layout.nodes.allSatisfy { !$0.isMerge })

        // Two edges: c -> b and b -> a, all in lane 0, none a merge parent.
        #expect(layout.edges.count == 2)
        #expect(layout.edges.allSatisfy { $0.fromLane == 0 && $0.toLane == 0 })
        #expect(layout.edges.allSatisfy { !$0.isMergeParent })
    }

    @Test func nodeAtRowFindsTheRightCommit() {
        let layout = CommitGraphBuilder.build(from: [
            commit("c", parents: ["b"]),
            commit("b", parents: ["a"]),
            commit("a", parents: [])
        ])
        #expect(layout.node(atRow: 0)?.id == "c")
        #expect(layout.node(atRow: 2)?.id == "a")
        #expect(layout.node(atRow: 99) == nil)
    }

    // MARK: - Merge

    @Test func mergeCommitSpawnsASecondLaneAndMergeEdge() {
        // m merges a (first parent) and b (second parent); both reach base.
        let layout = CommitGraphBuilder.build(from: [
            commit("m", parents: ["a", "b"]),
            commit("a", parents: ["base"]),
            commit("b", parents: ["base"]),
            commit("base", parents: [])
        ])

        #expect(layout.nodes.count == 4)
        #expect(layout.laneCount == 2)

        let merge = layout.nodes.first { $0.id == "m" }
        #expect(merge?.isMerge == true)

        // Exactly one edge represents the non-first parent of the merge, and it
        // lands in the side lane (lane 1) that b was placed on.
        let mergeEdges = layout.edges.filter { $0.isMergeParent }
        #expect(mergeEdges.count == 1)
        #expect(mergeEdges.first?.fromLane == 0)   // edge starts at the merge node's lane
        #expect(mergeEdges.first?.toLane == 1)     // b lives in the second lane
    }

    // MARK: - Out-of-view parent

    @Test func parentBeyondViewDropsTheEdgeButKeepsTheNode() {
        // The parent hash is not among the commits (e.g. beyond maxCount), so no
        // edge can be drawn - but the child node still exists.
        let layout = CommitGraphBuilder.build(from: [
            commit("c", parents: ["missing"])
        ])

        #expect(layout.nodes.count == 1)
        #expect(layout.edges.isEmpty)
        #expect(layout.laneCount == 1)
    }
}
