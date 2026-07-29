//
//  TagsTabView.swift
//  Maple
//
//  Created by Pool Camacho on 7/28/26.
//

import SwiftUI

struct TagsTabView: View {
    @Bindable var state: AppState
    @State private var showCreate = false
    @State private var tagPendingDeletion: GitTag?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tagList
        }
    }

    // Sheet lives on the header and the delete confirmation on the list, so the
    // two presentations are on separate subviews. Attaching both to the same
    // view makes macOS briefly flash the confirmation dialog before the sheet.
    private var header: some View {
        HStack {
            Text("Tags")
                .font(.headline)
            Spacer()
            Button {
                showCreate = true
            } label: {
                Label("New Tag", systemImage: "plus")
            }
            .controlSize(.small)
            .disabled(state.selectedRepository == nil)
            .accessibilityIdentifier("tags.new")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .sheet(isPresented: $showCreate) {
            NewTagDialog(state: state)
        }
    }

    @ViewBuilder
    private var tagList: some View {
        Group {
            if state.filteredTags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text(state.tags.isEmpty ? "No tags" : "No matching tags")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if state.tags.isEmpty {
                        Text("Use New Tag to create one")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(state.filteredTags) { tag in
                        TagRow(tag: tag)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    tagPendingDeletion = tag
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Delete tag?",
            isPresented: Binding(
                get: { tagPendingDeletion != nil },
                set: { if !$0 { tagPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: tagPendingDeletion
        ) { tag in
            Button("Delete", role: .destructive) {
                Task { await state.coordinator.deleteTag(tag) }
                tagPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { tagPendingDeletion = nil }
        } message: { tag in
            Text("This deletes the local tag \"\(tag.name)\".")
        }
    }
}

struct TagRow: View {
    let tag: GitTag

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !tag.subject.isEmpty {
                    Text(tag.subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !tag.targetShortSHA.isEmpty {
                Text(tag.targetShortSHA)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
