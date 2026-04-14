//
//  StagingAreaView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct StagingAreaView: View {
    @Bindable var state: AppState
    @State private var commitMessage: String = ""
    @State private var amendMode: Bool = false
    @State private var activeSection: String = "unstaged"

    private var stagedFiles: [GitFileChange] {
        state.fileChanges.filter { $0.isStaged }
    }

    private var unstagedFiles: [GitFileChange] {
        state.fileChanges.filter { !$0.isStaged }
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.fileChanges.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("Working tree clean")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FileChangeSection(
                    title: "Unstaged Changes",
                    count: unstagedFiles.count,
                    files: unstagedFiles,
                    selectedFile: $state.selectedFileChange,
                    sectionID: "unstaged",
                    activeSection: $activeSection,
                    actionIcon: "plus.circle.fill",
                    actionColor: .green,
                    onAction: { file in Task { await state.coordinator.stageFile(file) } },
                    bulkActionLabel: "Stage All",
                    onBulkAction: { Task { await state.coordinator.stageAllFiles() } }
                )

                Divider()

                FileChangeSection(
                    title: "Staged Changes",
                    count: stagedFiles.count,
                    files: stagedFiles,
                    selectedFile: $state.selectedFileChange,
                    sectionID: "staged",
                    activeSection: $activeSection,
                    actionIcon: "minus.circle.fill",
                    actionColor: .red,
                    onAction: { file in Task { await state.coordinator.unstageFile(file) } },
                    bulkActionLabel: "Unstage All",
                    onBulkAction: { Task { await state.coordinator.unstageAllFiles() } }
                )

                Divider()

                VStack(spacing: 8) {
                    TextEditor(text: $commitMessage)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 40, idealHeight: 60, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Group {
                                if commitMessage.isEmpty {
                                    Text("Commit message...")
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 12)
                                        .padding(.top, 16)
                                }
                            },
                            alignment: .topLeading
                        )

                    HStack {
                        Toggle("Amend", isOn: $amendMode)
                            .toggleStyle(.checkbox)
                            .font(.caption)

                        Spacer()

                        Button(action: {
                            let msg = commitMessage
                            let amend = amendMode
                            commitMessage = ""
                            Task { await state.coordinator.performCommit(message: msg, amend: amend) }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Commit")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled((stagedFiles.isEmpty && !amendMode) || commitMessage.isEmpty || state.operationInProgress)
                    }
                }
                .padding(10)
            }
        }
    }
}

struct FileChangeSection: View {
    let title: String
    let count: Int
    let files: [GitFileChange]
    @Binding var selectedFile: GitFileChange?
    let sectionID: String
    @Binding var activeSection: String
    let actionIcon: String
    let actionColor: Color
    let onAction: (GitFileChange) -> Void
    let bulkActionLabel: String
    let onBulkAction: () -> Void

    // Only show selection if this section is active
    private var sectionSelection: Binding<GitFileChange?> {
        Binding(
            get: { activeSection == sectionID ? selectedFile : nil },
            set: { newValue in
                if let newValue {
                    activeSection = sectionID
                    selectedFile = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())

                Spacer()

                if !files.isEmpty {
                    Button(bulkActionLabel) {
                        onBulkAction()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            List(selection: sectionSelection) {
                ForEach(files) { file in
                    FileChangeRow(file: file, actionIcon: actionIcon, actionColor: actionColor) {
                        onAction(file)
                    }
                    .tag(file)
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                }
            }
            .listStyle(.plain)
            .frame(minHeight: 50)
        }
    }
}

struct FileChangeRow: View {
    let file: GitFileChange
    let actionIcon: String
    let actionColor: Color
    let onAction: () -> Void

    private var statusColor: Color {
        switch file.status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .untracked: return .gray
        case .conflicted: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(file.status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
                .frame(width: 14)

            Text(file.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 4)

            Button(action: onAction) {
                Image(systemName: actionIcon)
                    .foregroundStyle(actionColor)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    StagingAreaView(state: AppState())
        .frame(width: 350, height: 600)
}
