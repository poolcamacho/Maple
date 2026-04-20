//
//  ChangesTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

private struct HunkStagingToolbar: View {
    @Bindable var state: AppState

    private var isStagedView: Bool {
        state.selectedFileChange?.isStaged ?? false
    }

    private var selectedLineCount: Int {
        state.selectedLines.values.reduce(0) { $0 + $1.count }
    }

    private var modifiableLineCount: Int {
        guard let file = state.currentDiffFile else { return 0 }
        return file.hunks.reduce(0) { total, hunk in
            total + hunk.lines.reduce(0) { count, line in
                count + ((line.type == .addition || line.type == .deletion) ? 1 : 0)
            }
        }
    }

    private var allSelected: Bool {
        modifiableLineCount > 0 && selectedLineCount == modifiableLineCount
    }

    private var hasSelection: Bool { selectedLineCount > 0 }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if allSelected {
                    state.selectedLines = [:]
                } else {
                    state.selectedLines = Self.allLines(in: state.currentDiffFile)
                }
            } label: {
                Text(allSelected ? "Deselect all" : "Select all")
            }
            .disabled(modifiableLineCount == 0)

            Text("\(selectedLineCount) of \(modifiableLineCount) lines")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if isStagedView {
                Button {
                    Task { await state.coordinator.unstageSelectedLines() }
                } label: {
                    Label("Unstage selected", systemImage: "minus.circle")
                }
                .disabled(!hasSelection || state.operationInProgress)
            } else {
                Button {
                    Task { await state.coordinator.stageSelectedLines() }
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

    private static func allLines(in file: DiffFile?) -> [Int: Set<Int>] {
        guard let file else { return [:] }
        var out: [Int: Set<Int>] = [:]
        for (hunkIndex, hunk) in file.hunks.enumerated() {
            let indices = DiffView.modifiableIndices(in: hunk)
            if !indices.isEmpty {
                out[hunkIndex] = indices
            }
        }
        return out
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
                        selection: state.currentDiffFile != nil ? $state.selectedLines : nil
                    )
                case .blame:
                    BlameView(fileName: state.selectedFileChange?.path, blameLines: state.currentBlameLines)
                }
            }
        }
    }
}
