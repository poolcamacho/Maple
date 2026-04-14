//
//  ToolbarView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct ToolbarView: View {
    @Bindable var state: AppState
    var availableWidth: CGFloat = 800
    @Binding var showNewBranch: Bool
    @Binding var showStashSave: Bool
    @Binding var showMerge: Bool
    @Binding var showRebase: Bool

    private var isCompact: Bool { availableWidth < 600 }
    private var isNarrow: Bool { availableWidth < 420 }

    var body: some View {
        HStack(spacing: isCompact ? 6 : 12) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.green)
                if !isNarrow {
                    Text(state.selectedRepository?.currentBranch ?? "No branch")
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            if !isNarrow {
                Divider()
                    .frame(height: 20)
            }

            Group {
                if isNarrow {
                    ToolbarIconButton(icon: "arrow.down.circle", color: .blue, help: "Pull") {
                        Task { await state.coordinator.performPull() }
                    }
                    ToolbarIconButton(icon: "arrow.up.circle", color: .green, help: "Push") {
                        Task { await state.coordinator.performPush() }
                    }
                } else if isCompact {
                    ToolbarIconButton(icon: "arrow.down.circle", color: .blue, help: "Pull") {
                        Task { await state.coordinator.performPull() }
                    }
                    ToolbarIconButton(icon: "arrow.up.circle", color: .green, help: "Push") {
                        Task { await state.coordinator.performPush() }
                    }
                    ToolbarIconButton(icon: "arrow.down.doc", color: .cyan, help: "Fetch") {
                        Task { await state.coordinator.performFetch() }
                    }
                    ToolbarIconButton(icon: "arrow.uturn.backward.circle", color: .orange, help: "Stash") {
                        showStashSave = true
                    }

                    Divider()
                        .frame(height: 20)

                    ToolbarIconButton(icon: "plus.circle", color: .teal, help: "Branch") {
                        showNewBranch = true
                    }
                    ToolbarIconButton(icon: "arrow.triangle.merge", color: .purple, help: "Merge") {
                        showMerge = true
                    }
                    ToolbarIconButton(icon: "arrow.triangle.branch", color: .orange, help: "Rebase") {
                        showRebase = true
                    }
                } else {
                    ToolbarActionButton(icon: "arrow.down.circle", label: "Pull", color: .blue) {
                        Task { await state.coordinator.performPull() }
                    }
                    ToolbarActionButton(icon: "arrow.up.circle", label: "Push", color: .green) {
                        Task { await state.coordinator.performPush() }
                    }
                    ToolbarActionButton(icon: "arrow.down.doc", label: "Fetch", color: .cyan) {
                        Task { await state.coordinator.performFetch() }
                    }
                    ToolbarActionButton(icon: "arrow.uturn.backward.circle", label: "Stash", color: .orange) {
                        showStashSave = true
                    }

                    Divider()
                        .frame(height: 20)

                    ToolbarActionButton(icon: "plus.circle", label: "Branch", color: .teal) {
                        showNewBranch = true
                    }
                    ToolbarActionButton(icon: "arrow.triangle.merge", label: "Merge", color: .purple) {
                        showMerge = true
                    }
                    ToolbarActionButton(icon: "arrow.triangle.branch", label: "Rebase", color: .orange) {
                        showRebase = true
                    }
                }
            }
            .disabled(state.operationInProgress)

            Spacer()

            if state.operationInProgress {
                ProgressView()
                    .controlSize(.small)
            }

            // Success banner clears itself after 3s.
            if let msg = state.successMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        state.successMessage = nil
                    }
            }

            if !isNarrow {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $state.searchText)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 50, maxWidth: isCompact ? 110 : 180)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            } else {
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isCompact ? 8 : 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct ToolbarActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44)
        .help(label)
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let color: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .frame(width: 28)
        .help(help)
    }
}

#Preview("Full") {
    ToolbarView(
        state: AppState(),
        availableWidth: 800,
        showNewBranch: .constant(false),
        showStashSave: .constant(false),
        showMerge: .constant(false),
        showRebase: .constant(false)
    )
    .frame(width: 800)
}
