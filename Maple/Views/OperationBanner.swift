//
//  OperationBanner.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

/// Persistent banner shown while a merge/rebase/cherry-pick is in progress.
/// Offers Abort / Continue actions and surfaces how many conflicts remain.
struct OperationBanner: View {
    @Bindable var state: AppState

    private var conflictCount: Int {
        state.fileChanges.filter { $0.status == .conflicted }.count
    }

    private var canContinue: Bool {
        conflictCount == 0
    }

    private var accentColor: Color {
        switch state.operationState {
        case .merging: return .purple
        case .rebasing: return .orange
        case .cherryPicking: return .teal
        case .reverting: return .red
        case .idle: return .clear
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.operationState.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(conflictSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Abort") {
                Task {
                    switch state.operationState {
                    case .merging: await state.coordinator.abortMerge()
                    case .rebasing: await state.coordinator.abortRebase()
                    default: break
                    }
                }
            }
            .controlSize(.small)
            .disabled(state.operationInProgress)

            if case .rebasing = state.operationState, conflictCount > 0 {
                Button("Skip") {
                    Task { await state.coordinator.skipRebase() }
                }
                .controlSize(.small)
                .disabled(state.operationInProgress)
            }

            Button("Continue") {
                Task {
                    switch state.operationState {
                    case .merging: await state.coordinator.continueMerge()
                    case .rebasing: await state.coordinator.continueRebase()
                    default: break
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!canContinue || state.operationInProgress)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(accentColor.opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle().fill(accentColor.opacity(0.4)).frame(height: 1)
        }
    }

    private var iconName: String {
        switch state.operationState {
        case .merging: return "arrow.triangle.merge"
        case .rebasing: return "arrow.triangle.branch"
        case .cherryPicking: return "leaf.fill"
        case .reverting: return "arrow.uturn.backward.circle.fill"
        case .idle: return "circle"
        }
    }

    private var conflictSummary: String {
        if conflictCount == 0 {
            return "No conflicts remain — you can continue"
        }
        return "\(conflictCount) file\(conflictCount == 1 ? "" : "s") with conflicts to resolve"
    }
}
