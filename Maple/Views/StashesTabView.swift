//
//  StashesTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct StashesTabView: View {
    @Bindable var state: AppState
    @State private var stashPendingDrop: GitStashEntry?

    var body: some View {
        content
            .confirmationDialog(
                "Drop stash?",
                isPresented: Binding(
                    get: { stashPendingDrop != nil },
                    set: { if !$0 { stashPendingDrop = nil } }
                ),
                titleVisibility: .visible,
                presenting: stashPendingDrop
            ) { entry in
                Button("Drop", role: .destructive) {
                    Task { await state.coordinator.performStashDrop(index: entry.index) }
                    stashPendingDrop = nil
                }
                Button("Cancel", role: .cancel) { stashPendingDrop = nil }
            } message: { entry in
                Text("This permanently discards the stash \"\(entry.message)\". It cannot be undone.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if state.stashes.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("No stashes")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Use the Stash button to save changes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(state.stashes) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.message)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text(entry.id)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Text(entry.relativeDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button("Apply") {
                                Task { await state.coordinator.performStashApply(index: entry.index) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Pop") {
                                Task { await state.coordinator.performStashPop(index: entry.index) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button(role: .destructive) {
                                stashPendingDrop = entry
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }
}
