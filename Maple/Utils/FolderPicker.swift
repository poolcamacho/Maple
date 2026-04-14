//
//  FolderPicker.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI
import AppKit

func openFolderPicker(state: AppState) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select a Git repository folder"
    panel.prompt = "Open"

    if panel.runModal() == .OK, let url = panel.url {
        Task {
            await state.coordinator.openRepository(at: url.path)
        }
    }
}
