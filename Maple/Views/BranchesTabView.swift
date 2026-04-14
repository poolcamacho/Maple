//
//  BranchesTabView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct BranchesTabView: View {
    @Bindable var state: AppState
    let availableWidth: CGFloat
    @State private var selectedBranch: GitBranch?

    private var isCompact: Bool { availableWidth < 500 }

    private var localBranches: [GitBranch] { state.branches.filter { !$0.isRemote } }
    private var remoteBranches: [GitBranch] { state.branches.filter { $0.isRemote } }

    var body: some View {
        if isCompact {
            branchList
        } else {
            HStack(spacing: 0) {
                branchList
                    .frame(width: min(max(availableWidth * 0.4, 200), 350))
                Divider()
                branchDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var branchList: some View {
        List(selection: $selectedBranch) {
            Section("Local Branches") {
                ForEach(localBranches) { branch in
                    BranchRow(branch: branch)
                        .tag(branch)
                        .contextMenu {
                            if !branch.isCurrent {
                                Button("Checkout") {
                                    Task { await state.coordinator.checkoutBranch(branch) }
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    Task { await state.coordinator.deleteLocalBranch(branch) }
                                }
                            } else {
                                Text("Current branch")
                            }
                        }
                }
            }

            Section("Remote Branches") {
                ForEach(remoteBranches) { branch in
                    BranchRow(branch: branch)
                        .tag(branch)
                        .contextMenu {
                            Button("Checkout as Local Branch") {
                                Task { await state.coordinator.checkoutBranch(branch) }
                            }
                        }
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var branchDetail: some View {
        if let branch = selectedBranch {
            VStack(spacing: 12) {
                Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                    .font(.system(size: 36))
                    .foregroundStyle(branch.isCurrent ? .green : .secondary)

                Text(branch.name)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)

                if branch.isCurrent {
                    Text("Current branch")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if branch.isRemote {
                    Text("Remote branch")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Button("Checkout as Local Branch") {
                        Task { await state.coordinator.checkoutBranch(branch) }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 12) {
                        Button("Checkout") {
                            Task { await state.coordinator.checkoutBranch(branch) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Delete", role: .destructive) {
                            Task { await state.coordinator.deleteLocalBranch(branch) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Select a branch")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BranchRow: View {
    let branch: GitBranch

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(branch.isCurrent ? .green : .secondary)
                .font(.caption)

            Image(systemName: branch.isRemote ? "cloud" : "arrow.triangle.branch")
                .foregroundStyle(branch.isRemote ? .blue : .primary)
                .font(.caption)

            Text(branch.name)
                .font(.system(.body, design: .monospaced))
                .fontWeight(branch.isCurrent ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if branch.isCurrent {
                Text("HEAD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}
