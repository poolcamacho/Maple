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
