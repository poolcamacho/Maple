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
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(diffLines) { line in
                            DiffLineView(line: line)
                        }
                    }
                }
            }
        }
    }

    private var additions: Int {
        diffLines.filter { $0.type == .addition }.count
    }

    private var deletions: Int {
        diffLines.filter { $0.type == .deletion }.count
    }
}

struct DiffLineView: View {
    let line: DiffLine

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
}

#Preview {
    DiffView(fileName: "Maple/Views/SidebarView.swift", diffLines: [])
        .frame(width: 700, height: 400)
}
