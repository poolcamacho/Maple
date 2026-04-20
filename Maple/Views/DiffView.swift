//
//  DiffView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct DiffView: View {
    let fileName: String?
    let diffLines: [DiffLine]
    var diffFile: DiffFile?
    var selection: Binding<[Int: Set<Int>]>?

    init(
        fileName: String?,
        diffLines: [DiffLine],
        diffFile: DiffFile? = nil,
        selection: Binding<[Int: Set<Int>]>? = nil
    ) {
        self.fileName = fileName
        self.diffLines = diffLines
        self.diffFile = diffFile
        self.selection = selection
    }

    var body: some View {
        VStack(spacing: 0) {
            if let fileName {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text(fileName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if !diffLines.isEmpty {
                        HStack(spacing: 8) {
                            Text("+\(additions)")
                                .foregroundStyle(.green)
                            Text("-\(deletions)")
                                .foregroundStyle(.red)
                        }
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()
            }

            if diffLines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: fileName != nil ? "doc.text" : "arrow.left.circle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(fileName != nil ? "No changes to display" : "Select a file to view diff")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let file = diffFile, let selection {
                structuredBody(file: file, selection: selection)
            } else {
                flatBody
            }
        }
    }

    private var flatBody: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(diffLines) { line in
                    DiffLineView(line: line)
                }
            }
        }
    }

    private func structuredBody(
        file: DiffFile,
        selection: Binding<[Int: Set<Int>]>
    ) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(file.hunks.enumerated()), id: \.offset) { hunkIndex, hunk in
                    HunkHeaderRow(
                        header: hunk.header,
                        isSelected: headerBinding(hunk: hunk, hunkIndex: hunkIndex, selection: selection)
                    )
                    ForEach(Array(hunk.lines.enumerated()), id: \.offset) { lineIndex, line in
                        switch line.type {
                        case .addition, .deletion:
                            DiffLineView(
                                line: line,
                                isSelected: lineBinding(
                                    hunkIndex: hunkIndex,
                                    lineIndex: lineIndex,
                                    selection: selection
                                ),
                                reservesSelectionSlot: true
                            )
                        case .context, .header:
                            DiffLineView(line: line, reservesSelectionSlot: true)
                        }
                    }
                }
            }
        }
    }

    private func headerBinding(
        hunk: DiffHunk,
        hunkIndex: Int,
        selection: Binding<[Int: Set<Int>]>
    ) -> Binding<Bool> {
        let modifiable: Set<Int> = Self.modifiableIndices(in: hunk)
        return Binding(
            get: {
                guard !modifiable.isEmpty else { return false }
                return selection.wrappedValue[hunkIndex] == modifiable
            },
            set: { newValue in
                if newValue {
                    selection.wrappedValue[hunkIndex] = modifiable
                } else {
                    selection.wrappedValue.removeValue(forKey: hunkIndex)
                }
            }
        )
    }

    private func lineBinding(
        hunkIndex: Int,
        lineIndex: Int,
        selection: Binding<[Int: Set<Int>]>
    ) -> Binding<Bool> {
        Binding(
            get: { selection.wrappedValue[hunkIndex]?.contains(lineIndex) ?? false },
            set: { newValue in
                var current = selection.wrappedValue[hunkIndex] ?? []
                if newValue {
                    current.insert(lineIndex)
                } else {
                    current.remove(lineIndex)
                }
                if current.isEmpty {
                    selection.wrappedValue.removeValue(forKey: hunkIndex)
                } else {
                    selection.wrappedValue[hunkIndex] = current
                }
            }
        )
    }

    static func modifiableIndices(in hunk: DiffHunk) -> Set<Int> {
        var out: Set<Int> = []
        for (idx, line) in hunk.lines.enumerated() where line.type == .addition || line.type == .deletion {
            out.insert(idx)
        }
        return out
    }

    private var additions: Int {
        diffLines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        diffLines.filter { $0.type == .deletion }.count
    }
}

private struct HunkHeaderRow: View {
    let header: String
    @Binding var isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(.leading, 8)

            Text("@@")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.blue)

            Text(header)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.vertical, 3)
        .background(.blue.opacity(0.08))
    }
}

struct DiffLineView: View {
    let line: DiffLine
    var isSelected: Binding<Bool>?
    var reservesSelectionSlot: Bool = false

    init(
        line: DiffLine,
        isSelected: Binding<Bool>? = nil,
        reservesSelectionSlot: Bool = false
    ) {
        self.line = line
        self.isSelected = isSelected
        self.reservesSelectionSlot = reservesSelectionSlot
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition: return .green.opacity(0.12)
        case .deletion: return .red.opacity(0.12)
        case .header: return .blue.opacity(0.08)
        case .context: return .clear
        }
    }

    private var linePrefix: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .header: return "@@"
        case .context: return " "
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .addition: return .green
        case .deletion: return .red
        case .header: return .blue
        case .context: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if let isSelected {
                Toggle("", isOn: isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .padding(.horizontal, 4)
                    .frame(width: slotWidth)
            } else if reservesSelectionSlot {
                Color.clear.frame(width: slotWidth)
            }

            HStack(spacing: 2) {
                Text(line.oldLineNumber.map { String($0) } ?? "")
                    .frame(width: 38, alignment: .trailing)
                Text(line.newLineNumber.map { String($0) } ?? "")
                    .frame(width: 38, alignment: .trailing)
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.tertiary)
            .padding(.trailing, 6)
            .background(.quaternary.opacity(0.3))

            Text(linePrefix)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(prefixColor)
                .frame(width: 16, alignment: .center)

            Text(line.content)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
        .padding(.vertical, 1.5)
        .background(backgroundColor)
    }

    private var slotWidth: CGFloat { 28 }
}

#Preview {
    DiffView(fileName: "Maple/Views/SidebarView.swift", diffLines: [])
        .frame(width: 700, height: 400)
}
