//
//  Dialogs.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct NewBranchDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var branchName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("New Branch")
                .font(.headline)

            TextField("Branch name", text: $branchName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { create() }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    create()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(branchName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func create() {
        let name = branchName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        dismiss()
        // Delay the async work so the sheet finishes dismissing
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.createNewBranch(name: name)
        }
    }
}

struct StashSaveDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Stash Changes")
                .font(.headline)

            TextField("Stash message (optional)", text: $message)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { save() }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Stash") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private func save() {
        let msg = message.trimmingCharacters(in: .whitespaces)
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.performStashSave(message: msg.isEmpty ? nil : msg)
        }
    }
}

// MARK: - Merge

struct MergeDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = ""

    private var candidateBranches: [GitBranch] {
        let current = state.selectedRepository?.currentBranch
        return state.branches.filter { !$0.isCurrent && $0.name != current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge Branch Into \(state.selectedRepository?.currentBranch ?? "current")")
                .font(.headline)

            Picker("Branch", selection: $selected) {
                Text("Choose a branch…").tag("")
                ForEach(candidateBranches) { branch in
                    Text(branch.isRemote ? "📡 \(branch.name)" : branch.name).tag(branch.name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 320)

            Text("A new merge commit will be created. If conflicts arise, you'll be able to resolve them from the Changes tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 340, alignment: .leading)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Merge") { start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
    }

    private func start() {
        let branch = selected
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.performMerge(branch: branch)
        }
    }
}

// MARK: - Rebase

struct RebaseDialog: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = ""

    private var candidateBranches: [GitBranch] {
        let current = state.selectedRepository?.currentBranch
        return state.branches.filter { !$0.isCurrent && $0.name != current }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rebase \(state.selectedRepository?.currentBranch ?? "current") onto…")
                .font(.headline)

            Picker("Onto", selection: $selected) {
                Text("Choose a branch…").tag("")
                ForEach(candidateBranches) { branch in
                    Text(branch.isRemote ? "📡 \(branch.name)" : branch.name).tag(branch.name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 320)

            Text(
                "Commits from the current branch will be replayed on top of the selected branch. "
                + "Conflicts can be resolved per-commit from the Changes tab."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 340, alignment: .leading)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rebase") { start() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
    }

    private func start() {
        let branch = selected
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            await state.coordinator.performRebase(onto: branch)
        }
    }
}
