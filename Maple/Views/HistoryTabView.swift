//
//  HistoryTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct HistoryTabView: View {
    @Bindable var state: AppState
    let availableWidth: CGFloat

    private var hasSelection: Bool {
        state.selectedCommit != nil && !state.commitDiffLines.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CommitHistoryView(state: state, availableWidth: availableWidth)
                    .frame(height: hasSelection ? geometry.size.height * 0.55 : geometry.size.height)
                    .clipped()

                if hasSelection {
                    Divider()

                    DiffView(
                        fileName: state.selectedCommit.map { "Commit \($0.shortID)" },
                        diffLines: state.commitDiffLines
                    )
                    .frame(height: geometry.size.height * 0.45 - 1)
                    .clipped()
                }
            }
        }
    }
}
