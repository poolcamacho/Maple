//
//  ChangesTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

private struct HunkStagingToolbar: View {
    @Bindable var state: AppState

    private var hasSelection: Bool { !state.selectedHunks.isEmpty }

    private var isStagedView: Bool {
        state.selectedFileChange?.isStaged ?? false
    }

    private var hunkCount: Int {
        state.currentDiffFile?.hunks.count ?? 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if state.selectedHunks.count == hunkCount {
                    state.selectedHunks = []
                } else {
                    state.selectedHunks = Set(0..<hunkCount)
                }
            } label: {
                Text(state.selectedHunks.count == hunkCount && hunkCount > 0 ? "Deselect all" : "Select all")
            }
            .disabled(hunkCount == 0)

            Text("\(state.selectedHunks.count) of \(hunkCount) hunks")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if isStagedView {
                Button {
                    Task { await state.coordinator.unstageSelectedHunks() }
                } label: {
                    Label("Unstage selected", systemImage: "minus.circle")
                }
                .disabled(!hasSelection || state.operationInProgress)
            } else {
                Button {
                    Task { await state.coordinator.stageSelectedHunks() }
                } label: {
                    Label("Stage selected", systemImage: "plus.circle")
                }
                .disabled(!hasSelection || state.operationInProgress)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

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
                    if state.currentDiffFile != nil {
                        HunkStagingToolbar(state: state)
                        Divider()
                    }
                    DiffView(
                        fileName: state.selectedFileChange?.path,
                        diffLines: state.currentDiffLines,
                        diffFile: state.currentDiffFile,
                        selection: state.currentDiffFile != nil ? $state.selectedHunks : nil
                    )
                case .blame:
                    BlameView(fileName: state.selectedFileChange?.path, blameLines: state.currentBlameLines)
                }
            }
        }
    }
}
