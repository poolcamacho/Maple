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

    var body: some View {
        Canvas { context, _ in
            let laneOffset: CGFloat = 12  // leading padding before lane 0

            func xFor(lane: Int) -> CGFloat {
                laneOffset + CGFloat(lane) * laneWidth + laneWidth / 2
            }

            // 1) Edges touching this row
            for edge in layout.edges {
                guard edge.fromRow <= rowIndex, rowIndex <= edge.toRow else { continue }

                let fromX = xFor(lane: edge.fromLane)
                let toX = xFor(lane: edge.toLane)
                let color = CommitGraphColors.color(forLane: edge.toLane)

                var path = Path()

                if edge.fromRow == rowIndex && edge.toRow == rowIndex {
                    // Degenerate same-row edge (shouldn't happen with parent relationships)
                    path.move(to: CGPoint(x: fromX, y: rowHeight / 2))
                    path.addLine(to: CGPoint(x: toX, y: rowHeight / 2))
                } else if edge.fromRow == rowIndex {
                    // Start half: from commit center out to bottom edge, potentially curving to another lane
                    path.move(to: CGPoint(x: fromX, y: rowHeight / 2))
                    if fromX == toX {
                        path.addLine(to: CGPoint(x: toX, y: rowHeight))
                    } else {
                        path.addCurve(
                            to: CGPoint(x: toX, y: rowHeight),
                            control1: CGPoint(x: fromX, y: rowHeight * 0.82),
                            control2: CGPoint(x: toX, y: rowHeight * 0.68)
                        )
                    }
                } else if edge.toRow == rowIndex {
                    // End half: top edge down to commit center, vertical at destination lane
                    path.move(to: CGPoint(x: toX, y: 0))
                    path.addLine(to: CGPoint(x: toX, y: rowHeight / 2))
                } else {
                    // Crossing: vertical at destination lane from top to bottom
                    path.move(to: CGPoint(x: toX, y: 0))
                    path.addLine(to: CGPoint(x: toX, y: rowHeight))
                }

                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }

            // 2) Node circle for this row (drawn last so it sits above edges)
            if let node = layout.node(atRow: rowIndex) {
                let x = xFor(lane: node.lane)
                let y = rowHeight / 2
                let color = CommitGraphColors.color(forLane: node.lane)

                let diameter: CGFloat = node.isMerge ? 10 : 8
                let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)

                context.fill(Path(ellipseIn: rect), with: .color(color))

                if node.isMerge {
                    let outer = rect.insetBy(dx: -2.5, dy: -2.5)
                    context.stroke(Path(ellipseIn: outer), with: .color(color), lineWidth: 1.5)
                }
            }
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
