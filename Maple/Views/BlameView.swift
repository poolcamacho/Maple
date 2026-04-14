//
//  BlameView.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import SwiftUI

struct BlameView: View {
    let fileName: String?
    let blameLines: [BlameLine]

    var body: some View {
        VStack(spacing: 0) {
            if let fileName {
                HStack(spacing: 8) {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(.secondary)
                    Text(fileName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if !blameLines.isEmpty {
                        Text("\(blameLines.count) lines")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()
            }

            if blameLines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: fileName != nil ? "person.text.rectangle" : "arrow.left.circle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(fileName != nil ? "No blame data available" : "Select a file to view blame")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(blameLines.enumerated()), id: \.element.id) { index, line in
                            BlameLineView(
                                line: line,
                                showCommitInfo: index == 0 || blameLines[index - 1].commitHash != line.commitHash
                            )
                        }
                    }
                }
            }
        }
    }
}

struct BlameLineView: View {
    let line: BlameLine
    let showCommitInfo: Bool

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var hashColor: Color {
        let hash = line.commitHash
        guard !hash.isEmpty else { return .secondary }
        let slice = hash.prefix(6)
        let val = Int(slice, radix: 16) ?? 0
        let hue = Double(val % 360) / 360.0
        return Color(hue: hue, saturation: 0.4, brightness: 0.7)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                if showCommitInfo {
                    Text(line.shortHash)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(hashColor)
                    Text(line.author)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(Self.dateFormatter.string(from: line.date))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 220, alignment: .leading)
            .background(.quaternary.opacity(showCommitInfo ? 0.3 : 0.12))
            .help(showCommitInfo ? "\(line.shortHash) — \(line.author)\n\(line.summary)" : "")

            Text("\(line.lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 6)
                .background(.quaternary.opacity(0.18))

            Text(line.content)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .lineLimit(1)
        }
        .padding(.vertical, 1.5)
    }
}

#Preview {
    BlameView(fileName: "Maple/ContentView.swift", blameLines: [])
        .frame(width: 800, height: 500)
}
