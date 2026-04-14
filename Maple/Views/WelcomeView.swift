//
//  WelcomeView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct WelcomeView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Maple")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Open a Git repository to get started")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Open Repository...") {
                openFolderPicker(state: state)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
