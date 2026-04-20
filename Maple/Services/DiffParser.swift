//
//  DiffParser.swift
//  Maple
//
//  Created by Pool Camacho on 4/15/26.
//

import Foundation

/// Parses raw `git diff` / `git show` output into structured `DiffFile` /
/// `DiffLine` representations.
enum DiffParser {

    /// Structured view: one entry per file, each with its preamble preserved so
    /// a patch can be reconstructed for a subset of hunks later.
    static func parseFiles(_ output: String) -> [DiffFile] {
        var state = State()
        for raw in output.components(separatedBy: "\n") {
            state.consume(raw)
        }
        state.flushFile()
        return state.files
    }

    /// Flattened view kept for callers that render the diff as a single list.
    /// Hunk headers are emitted as `DiffLine(type: .header)`.
    static func parseFlat(_ output: String) -> [DiffLine] {
        var lines: [DiffLine] = []
        for file in parseFiles(output) {
            lines.append(contentsOf: file.flattened)
        }
        return lines
    }

    // MARK: - Helpers

    private struct HunkNumbers {
        let oldStart: Int
        let oldCount: Int
        let newStart: Int
        let newCount: Int
    }

    /// Parses a hunk header like `"@@ -10,3 +12,4 @@ optional context"` into its
    /// four numeric fields. Returns nil if the header is malformed.
    private static func parseHunkHeader(_ raw: String) -> HunkNumbers? {
        let parts = raw.components(separatedBy: " ")
        guard parts.count >= 3 else { return nil }
        let oldBits = parts[1].dropFirst().components(separatedBy: ",")
        let newBits = parts[2].dropFirst().components(separatedBy: ",")
        return HunkNumbers(
            oldStart: Int(oldBits.first ?? "0") ?? 0,
            oldCount: oldBits.count > 1 ? Int(oldBits[1]) ?? 1 : 1,
            newStart: Int(newBits.first ?? "0") ?? 0,
            newCount: newBits.count > 1 ? Int(newBits[1]) ?? 1 : 1
        )
    }

    private static let preamblePrefixes: [String] = [
        "index ", "--- ",
        "new file mode ", "deleted file mode ",
        "similarity index ", "rename from ", "rename to "
    ]

    private static func isPreambleLine(_ line: String) -> Bool {
        preamblePrefixes.contains(where: { line.hasPrefix($0) })
    }

    // MARK: - Parser state

    private struct State {
        var files: [DiffFile] = []
        var currentPreamble: [String] = []
        var currentPath: String?
        var currentHunks: [DiffHunk] = []
        var hunkHeader: String?
        var hunkNumbers = HunkNumbers(oldStart: 0, oldCount: 0, newStart: 0, newCount: 0)
        var hunkLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        mutating func consume(_ raw: String) {
            if raw.hasPrefix("diff --git") {
                flushFile()
                currentPreamble = [raw]
            } else if DiffParser.isPreambleLine(raw) {
                currentPreamble.append(raw)
            } else if raw.hasPrefix("+++ ") {
                currentPreamble.append(raw)
                capturePath(from: raw)
            } else if raw.hasPrefix("@@") {
                flushHunk()
                startHunk(header: raw)
            } else if raw.hasPrefix("+") {
                hunkLines.append(DiffLine(content: String(raw.dropFirst()), type: .addition, oldLineNumber: nil, newLineNumber: newLine))
                newLine += 1
            } else if raw.hasPrefix("-") {
                hunkLines.append(DiffLine(content: String(raw.dropFirst()), type: .deletion, oldLineNumber: oldLine, newLineNumber: nil))
                oldLine += 1
            } else if raw.hasPrefix(" ") {
                hunkLines.append(DiffLine(content: String(raw.dropFirst()), type: .context, oldLineNumber: oldLine, newLineNumber: newLine))
                oldLine += 1
                newLine += 1
            }
        }

        private mutating func capturePath(from raw: String) {
            let after = String(raw.dropFirst(4))
            if after.hasPrefix("b/") {
                currentPath = String(after.dropFirst(2))
            } else if after != "/dev/null" {
                currentPath = after
            }
        }

        private mutating func startHunk(header: String) {
            hunkHeader = header
            if let numbers = DiffParser.parseHunkHeader(header) {
                hunkNumbers = numbers
                oldLine = numbers.oldStart
                newLine = numbers.newStart
            }
        }

        mutating func flushHunk() {
            guard let header = hunkHeader else { return }
            currentHunks.append(DiffHunk(
                header: header,
                oldStart: hunkNumbers.oldStart,
                oldCount: hunkNumbers.oldCount,
                newStart: hunkNumbers.newStart,
                newCount: hunkNumbers.newCount,
                lines: hunkLines
            ))
            hunkHeader = nil
            hunkLines = []
        }

        mutating func flushFile() {
            flushHunk()
            guard !currentPreamble.isEmpty || !currentHunks.isEmpty else { return }
            files.append(DiffFile(path: currentPath, preamble: currentPreamble, hunks: currentHunks))
            currentPreamble = []
            currentPath = nil
            currentHunks = []
        }
    }
}
