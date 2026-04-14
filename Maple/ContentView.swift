//
//  ContentView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct ContentView: View {
    @State private var state = AppState()
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var showNewBranch = false
    @State private var showStashSave = false
    @State private var showMerge = false
    @State private var showRebase = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(state: state)
                .navigationSplitViewColumnWidth(min: 160, ideal: 220, max: 300)
        } detail: {
            if state.selectedRepository != nil {
                DetailAreaView(
                    state: state,
                    showNewBranch: $showNewBranch,
                    showStashSave: $showStashSave,
                    showMerge: $showMerge,
                    showRebase: $showRebase
                )
            } else {
                WelcomeView(state: state)
            }
        }
        .navigationTitle(state.selectedRepository?.name ?? "Maple")
        .frame(minWidth: 520, minHeight: 400)
        .onChange(of: state.selectedFileChange) {
            Task {
                await state.coordinator.loadFileDiff()
                if state.changesViewMode == .blame {
                    await state.coordinator.loadBlame()
                }
            }
        }
        .onChange(of: state.selectedCommit) {
            Task { await state.coordinator.loadCommitDiff() }
        }
        .onAppear {
            state.setupWatcher()
        }
        .sheet(isPresented: $showNewBranch) {
            NewBranchDialog(state: state)
        }
        .sheet(isPresented: $showStashSave) {
            StashSaveDialog(state: state)
        }
        .sheet(isPresented: $showMerge) {
            MergeDialog(state: state)
        }
        .sheet(isPresented: $showRebase) {
            RebaseDialog(state: state)
        }
    }
}

// MARK: - Detail Area

struct DetailAreaView: View {
    @Bindable var state: AppState
    @Binding var showNewBranch: Bool
    @Binding var showStashSave: Bool
    @Binding var showMerge: Bool
    @Binding var showRebase: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            VStack(spacing: 0) {
                ToolbarView(
                    state: state,
                    availableWidth: width,
                    showNewBranch: $showNewBranch,
                    showStashSave: $showStashSave,
                    showMerge: $showMerge,
                    showRebase: $showRebase
                )

                Divider()

                if state.operationState.isInProgress {
                    OperationBanner(state: state)
                }

                if state.isLoading {
                    ProgressView("Loading repository...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Picker("View", selection: $state.currentTab) {
                        ForEach(AppState.DetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Divider()

                    if let error = state.errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Dismiss") {
                                state.errorMessage = nil
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.top, 4)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch state.currentTab {
                        case .changes:
                            ChangesTabView(state: state, availableWidth: width)
                        case .history:
                            HistoryTabView(state: state, availableWidth: width)
                        case .branches:
                            BranchesTabView(state: state, availableWidth: width)
                        case .stashes:
                            StashesTabView(state: state)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
