//
//  GitModels.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

struct GitRepository: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    var currentBranch: String = "main"

    nonisolated init(name: String, path: String, currentBranch: String = "main") {
        self.id = path
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
    }
}

struct GitCommit: Identifiable, Sendable {
    let id: String
    let shortID: String
    let message: String
    let author: String
    let date: Date
    let branch: String?
    let parents: [String]

    nonisolated init(id: String, shortID: String, message: String, author: String, date: Date, branch: String?, parents: [String]) {
        self.id = id
        self.shortID = shortID
        self.message = message
        self.author = author
        self.date = date
        self.branch = branch
        self.parents = parents
    }
}

struct GitFileChange: Identifiable, Hashable, Sendable {
    let id: String
    let path: String
    let status: FileStatus
    var isStaged: Bool

    nonisolated init(path: String, status: FileStatus, isStaged: Bool) {
        self.id = "\(path):\(isStaged ? "staged" : "unstaged")"
        self.path = path
        self.status = status
        self.isStaged = isStaged
    }

    enum FileStatus: String, Sendable {
        case modified = "M"
        case added = "A"
        case deleted = "D"
        case renamed = "R"
        case untracked = "?"
        case conflicted = "!"
    }
}

enum RepoOperationState: Sendable, Equatable {
    case idle
    case merging(head: String?)      // contents of .git/MERGE_HEAD (short SHA or branch)
    case rebasing(head: String?)     // branch being rebased
    case cherryPicking
    case reverting

    var isInProgress: Bool {
        if case .idle = self { return false }
        return true
    }

    var label: String {
        switch self {
        case .idle: return ""
        case .merging(let head): return head.map { "Merging \($0)" } ?? "Merging"
        case .rebasing(let head): return head.map { "Rebasing \($0)" } ?? "Rebasing"
        case .cherryPicking: return "Cherry-picking"
        case .reverting: return "Reverting"
        }
    }
}

struct GitBranch: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isRemote: Bool
    let isCurrent: Bool

    nonisolated init(name: String, isRemote: Bool, isCurrent: Bool) {
        self.id = "\(isRemote ? "remote:" : "local:")\(name)"
        self.name = name
        self.isRemote = isRemote
        self.isCurrent = isCurrent
    }
}

/// A contiguous run of diff lines under a single `@@ ... @@` hunk header.
/// Carries the original header text so patches can be reconstructed without
/// re-parsing line numbers into the same format git expects.
struct DiffHunk: Identifiable, Sendable {
    let id = UUID()
    let header: String
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    let lines: [DiffLine]

    nonisolated init(
        header: String,
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        lines: [DiffLine]
    ) {
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.lines = lines
    }
}

/// One file's diff: the raw preamble lines (`diff --git`, `index`, `---`, `+++`)
/// grouped together with that file's hunks. Preserving the preamble is what
/// lets us round-trip a subset of hunks back into `git apply --cached`.
struct DiffFile: Identifiable, Sendable {
    let id = UUID()
    let path: String?
    let preamble: [String]
    let hunks: [DiffHunk]

    nonisolated init(path: String?, preamble: [String], hunks: [DiffHunk]) {
        self.path = path
        self.preamble = preamble
        self.hunks = hunks
    }

    /// Flattened view for rendering; mirrors the old `[DiffLine]` shape
    /// (hunk headers as `.header` lines, followed by their content lines).
    var flattened: [DiffLine] {
        var out: [DiffLine] = []
        for hunk in hunks {
            out.append(DiffLine(content: hunk.header, type: .header, oldLineNumber: nil, newLineNumber: nil))
            out.append(contentsOf: hunk.lines)
        }
        return out
    }

    /// Builds a patch string including only the hunks at the given indices.
    /// Only valid for whole-hunk selection (the hunk header's line counts stay
    /// truthful). Partial-line selection needs a different codepath that also
    /// rewrites those counts.
    func patchText(forHunkIndices selected: Set<Int>) -> String {
        guard !selected.isEmpty, !preamble.isEmpty else { return "" }
        var lines: [String] = preamble
        for (index, hunk) in hunks.enumerated() where selected.contains(index) {
            lines.append(hunk.header)
            for line in hunk.lines {
                switch line.type {
                case .addition: lines.append("+" + line.content)
                case .deletion: lines.append("-" + line.content)
                case .context: lines.append(" " + line.content)
                case .header: continue
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

struct BlameLine: Identifiable, Sendable {
    let id = UUID()
    let lineNumber: Int
    let content: String
    let commitHash: String
    let shortHash: String
    let author: String
    let date: Date
    let summary: String

    nonisolated init(lineNumber: Int, content: String, commitHash: String, shortHash: String, author: String, date: Date, summary: String) {
        self.lineNumber = lineNumber
        self.content = content
        self.commitHash = commitHash
        self.shortHash = shortHash
        self.author = author
        self.date = date
        self.summary = summary
    }
}

struct DiffLine: Identifiable, Sendable {
    let id = UUID()
    let content: String
    let type: LineType
    let oldLineNumber: Int?
    let newLineNumber: Int?

    nonisolated init(content: String, type: LineType, oldLineNumber: Int?, newLineNumber: Int?) {
        self.content = content
        self.type = type
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }

    enum LineType: Sendable {
        case context
        case addition
        case deletion
        case header
    }
}
