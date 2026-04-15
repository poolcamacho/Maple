//
//  CommitHistoryView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct CommitHistoryView: View {
    @Bindable var state: AppState
    var availableWidth: CGFloat = 800

    private var showAuthor: Bool { availableWidth > 550 }
    private var showDate: Bool { availableWidth > 450 }
    private var showSHA: Bool { availableWidth > 380 }

    private let rowHeight: CGFloat = 30
    private let laneWidth: CGFloat = 14

    private var layout: CommitGraphLayout {
        CommitGraphBuilder.build(from: state.commits)
    }

    private var graphWidth: CGFloat {
        max(40, CGFloat(layout.laneCount) * laneWidth + 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Commit History")
                    .font(.headline)
                Spacer()
                Text("\(state.commits.count) commits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            HStack(spacing: 0) {
                Text("Graph")
                    .frame(width: graphWidth, alignment: .leading)
                    .padding(.leading, 12)
                Text("Message")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showAuthor {
                    Text("Author")
                        .frame(width: 100, alignment: .leading)
                }
                if showDate {
                    Text("Date")
                        .frame(width: 80, alignment: .trailing)
                }
                if showSHA {
                    Text("SHA")
                        .frame(width: 64, alignment: .trailing)
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5))

            Divider()

            let currentLayout = layout
            List(selection: $state.selectedCommit) {
                ForEach(Array(state.commits.enumerated()), id: \.element.id) { index, commit in
                    CommitRow(
                        commit: commit,
                        rowIndex: index,
                        layout: currentLayout,
                        graphWidth: graphWidth,
                        laneWidth: laneWidth,
                        rowHeight: rowHeight,
                        showAuthor: showAuthor,
                        showDate: showDate,
                        showSHA: showSHA
                    )
                    .tag(commit)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .listStyle(.plain)
        }
    }
}

struct CommitRow: View {
    let commit: GitCommit
    let rowIndex: Int
    let layout: CommitGraphLayout
    let graphWidth: CGFloat
    let laneWidth: CGFloat
    let rowHeight: CGFloat
    var showAuthor: Bool = true
    var showDate: Bool = true
    var showSHA: Bool = true

    private var branchColor: Color {
        CommitGraphColors.color(forLane: layout.node(atRow: rowIndex)?.lane ?? 0)
    }

    var body: some View {
        HStack(spacing: 0) {
            CommitGraphRowCanvas(
                rowIndex: rowIndex,
                layout: layout,
                laneWidth: laneWidth,
                rowHeight: rowHeight
            )
            .frame(width: graphWidth, height: rowHeight)

            HStack(spacing: 6) {
                if let branch = commit.branch {
                    BranchTag(name: branch, color: branchColor)
                }
                Text(commit.message)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showAuthor {
                Text(commit.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }

            if showDate {
                Text(commit.date.relativeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }

            if showSHA {
                Text(commit.shortID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .padding(.trailing, 12)
        .frame(height: rowHeight)
        .contentShape(Rectangle())
    }
}

struct CommitGraphRowCanvas: View {
    let rowIndex: Int
    let layout: CommitGraphLayout
    let laneWidth: CGFloat
    let rowHeight: CGFloat

    private let edgeWidth: CGFloat = 2.0
    private let nodeDiameter: CGFloat = 9
    private let mergeInnerDiameter: CGFloat = 5
    private let mergeOuterDiameter: CGFloat = 13
    private let mergeRingWidth: CGFloat = 2.0
    private let laneOffset: CGFloat = 12

    var body: some View {
        Canvas { context, _ in
            func xFor(lane: Int) -> CGFloat {
                laneOffset + CGFloat(lane) * laneWidth + laneWidth / 2
            }

            for edge in layout.edges {
                guard edge.fromRow <= rowIndex, rowIndex <= edge.toRow else { continue }

                let fromX = xFor(lane: edge.fromLane)
                let toX = xFor(lane: edge.toLane)
                let color = CommitGraphColors.color(forLane: edge.toLane)
                let path = edgePath(from: fromX, to: toX, edgeFromRow: edge.fromRow, edgeToRow: edge.toRow)

                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: edgeWidth, lineCap: .round))
            }

            if let node = layout.node(atRow: rowIndex) {
                drawNode(node, in: context, xFor: xFor)
            }
        }
    }

    /// Returns the slice of the edge that lives in the current row. Lane transitions
    /// happen entirely inside the child row (the `fromRow` end) so branches visibly
    /// originate from the source commit rather than drifting across multiple rows.
    private func edgePath(from fromX: CGFloat, to toX: CGFloat, edgeFromRow: Int, edgeToRow: Int) -> Path {
        var path = Path()

        if edgeFromRow == rowIndex && edgeToRow == rowIndex {
            path.move(to: CGPoint(x: fromX, y: rowHeight / 2))
            path.addLine(to: CGPoint(x: toX, y: rowHeight / 2))
        } else if edgeFromRow == rowIndex {
            path.move(to: CGPoint(x: fromX, y: rowHeight / 2))
            if fromX == toX {
                path.addLine(to: CGPoint(x: toX, y: rowHeight))
            } else {
                // Smoother S: stay at source-x longer then sweep into target-x near the bottom
                path.addCurve(
                    to: CGPoint(x: toX, y: rowHeight),
                    control1: CGPoint(x: fromX, y: rowHeight * 0.75),
                    control2: CGPoint(x: toX, y: rowHeight * 0.80)
                )
            }
        } else if edgeToRow == rowIndex {
            path.move(to: CGPoint(x: toX, y: 0))
            path.addLine(to: CGPoint(x: toX, y: rowHeight / 2))
        } else {
            path.move(to: CGPoint(x: toX, y: 0))
            path.addLine(to: CGPoint(x: toX, y: rowHeight))
        }

        return path
    }

    /// Regular commit: filled dot. Merge: hollow ring with a small inner dot, so joins
    /// stay readable over vertical lane lines that cross behind them.
    private func drawNode(_ node: CommitGraphLayout.Node, in context: GraphicsContext, xFor: (Int) -> CGFloat) {
        let x = xFor(node.lane)
        let y = rowHeight / 2
        let color = CommitGraphColors.color(forLane: node.lane)

        if node.isMerge {
            let outerRect = CGRect(
                x: x - mergeOuterDiameter / 2,
                y: y - mergeOuterDiameter / 2,
                width: mergeOuterDiameter,
                height: mergeOuterDiameter
            )
            context.stroke(
                Path(ellipseIn: outerRect),
                with: .color(color),
                lineWidth: mergeRingWidth
            )

            let innerRect = CGRect(
                x: x - mergeInnerDiameter / 2,
                y: y - mergeInnerDiameter / 2,
                width: mergeInnerDiameter,
                height: mergeInnerDiameter
            )
            context.fill(Path(ellipseIn: innerRect), with: .color(color))
        } else {
            let rect = CGRect(
                x: x - nodeDiameter / 2,
                y: y - nodeDiameter / 2,
                width: nodeDiameter,
                height: nodeDiameter
            )
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}

struct BranchTag: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

#Preview {
    CommitHistoryView(state: AppState(), availableWidth: 800)
        .frame(width: 800, height: 400)
}
