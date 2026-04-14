//
//  SidebarView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState

    var body: some View {
        List(selection: $state.selectedRepository) {
            Section("Repositories") {
                ForEach(state.repositories) { repo in
                    SidebarRepoRow(repository: repo)
                        .tag(repo)
                }

                if state.repositories.isEmpty {
                    Text("No repositories")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }

            if !state.branches.isEmpty {
                Section("Branches") {
                    ForEach(state.branches.filter { !$0.isRemote }) { branch in
                        Label {
                            Text(branch.name)
                                .fontWeight(branch.isCurrent ? .semibold : .regular)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: branch.isCurrent ? "arrow.triangle.branch" : "line.diagonal")
                                .foregroundStyle(branch.isCurrent ? .green : .secondary)
                        }
                    }
                }

                Section("Remotes") {
                    ForEach(state.branches.filter { $0.isRemote }) { branch in
                        Label {
                            Text(branch.name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cloud")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button(action: { openFolderPicker(state: state) }) {
                    Image(systemName: "plus")
                }
                .help("Open Repository")
            }

            ToolbarItem {
                Button(action: {
                    Task { await state.coordinator.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }
}

struct SidebarRepoRow: View {
    let repository: GitRepository

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text(repository.currentBranch)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SidebarView(state: AppState())
        .frame(width: 250, height: 500)
}
