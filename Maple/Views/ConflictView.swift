//
//  ConflictView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

/// Shows a file currently in conflict state. Parses `<<<<<<<`, `=======`, `>>>>>>>`
/// markers and colorizes the three sides. Offers quick-resolution actions
/// (Use Ours / Use Theirs) that delegate to git's checkout --ours / --theirs.
struct ConflictView: View {
    @Bindable var state: AppState
    let file: GitFileChange?

    @State private var fileContent: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(file?.path ?? "No file selected")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()

                if file != nil {
                    Button {
                        guard let file else { return }
                        Task { await state.coordinator.useOurs(file: file) }
                    } label: {
                        Label("Use Ours", systemImage: "arrow.left.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Keep the version from the current branch and stage the file")

                    Button {
                        guard let file else { return }
                        Task { await state.coordinator.useTheirs(file: file) }
                    } label: {
                        Label("Use Theirs", systemImage: "arrow.right.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Keep the version from the incoming branch and stage the file")

                    Button {
                        Task { await loadFileContent() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Reload file contents")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if file == nil {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.circle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Select a conflicted file")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(parsedLines.enumerated()), id: \.offset) { index, line in
                            ConflictLineRow(lineNumber: index + 1, line: line)
                        }
                    }
                }
            }
        }
        .task(id: file?.id) {
            await loadFileContent()
        }
    }

    private func loadFileContent() async {
        guard let file, let path = state.currentRepoPath else {
            fileContent = ""
            return
        }
        isLoading = true
        let content = await state.git.readFileContent(file.path, in: path) ?? ""
        fileContent = content
        isLoading = false
    }

    private var parsedLines: [ConflictLine] {
        ConflictParser.parse(fileContent)
    }
}

struct ConflictLineRow: View {
    let lineNumber: Int
    let line: ConflictLine

    private var backgroundColor: Color {
        switch line.side {
        case .ours: return .blue.opacity(0.12)
        case .theirs: return .green.opacity(0.12)
        case .base: return .gray.opacity(0.12)
        case .markerOurs, .markerTheirs, .markerBase, .markerDivider: return .orange.opacity(0.2)
        case .normal: return .clear
        }
    }

    private var textColor: Color {
        switch line.side {
        case .markerOurs, .markerTheirs, .markerBase, .markerDivider: return .orange
        default: return .primary
        }
    }

    private var isMarker: Bool {
        switch line.side {
        case .markerOurs, .markerTheirs, .markerBase, .markerDivider: return true
        default: return false
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 6)
                .background(.quaternary.opacity(0.2))

            Text(line.content)
                .font(.system(size: 12, weight: isMarker ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
        .padding(.vertical, 1.5)
        .background(backgroundColor)
    }
}
