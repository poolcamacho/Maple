//
//  ChangesTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct ChangesTabView: View {
    @Bindable var state: AppState
    let availableWidth: CGFloat

    private var isCompact: Bool { availableWidth < 600 }

    private var blameAvailable: Bool {
        guard let file = state.selectedFileChange else { return false }
        return file.status != .untracked && file.status != .conflicted
    }

    private var showingConflict: Bool {
        state.selectedFileChange?.status == .conflicted
    }

    var body: some View {
        if isCompact {
            VStack(spacing: 0) {
                StagingAreaView(state: state)
                    .frame(maxHeight: .infinity)
                Divider()
                fileContentPanel
                    .frame(maxHeight: .infinity)
            }
        } else {
            HStack(spacing: 0) {
                StagingAreaView(state: state)
                    .frame(width: min(max(availableWidth * 0.35, 220), 400))
                Divider()
                fileContentPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var fileContentPanel: some View {
        VStack(spacing: 0) {
            if showingConflict {
                ConflictView(state: state, file: state.selectedFileChange)
            } else {
                Picker("View", selection: $state.changesViewMode) {
                    ForEach(AppState.ChangesViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .onChange(of: blameAvailable) { _, available in
                    if !available && state.changesViewMode == .blame {
                        state.changesViewMode = .diff
                    }
                }
                .onChange(of: state.changesViewMode) { _, mode in
                    if mode == .blame {
                        Task { await state.coordinator.loadBlame() }
                    }
                }

                Divider()

                switch state.changesViewMode {
                case .diff:
                    DiffView(fileName: state.selectedFileChange?.path, diffLines: state.currentDiffLines)
                case .blame:
                    BlameView(fileName: state.selectedFileChange?.path, blameLines: state.currentBlameLines)
                }
            }
        }
    }
}
