//
//  StatusParser.swift
//  Maple
//
//  Created by Pool Camacho on 7/28/26.
//

import Foundation

/// Parses `git status --porcelain=v2 -z` output into `GitFileChange` values.
///
/// Porcelain v2 with `-z` is NUL-delimited and prints paths verbatim: no C-style
/// quoting, no `->` rename encoding, no newline-delimited records. That removes
/// the whole class of v1 parsing bugs around paths with spaces, unicode, embedded
/// newlines, quotes, or names that literally contain " -> ".
///
/// Record shapes (each NUL-terminated):
///   `# ...`  branch headers, ignored
///   `1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>`               ordinary change
///   `2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <Xscore> <path>` + `<origPath>`  rename/copy
///   `u <xy> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>`     unmerged (conflict)
///   `? <path>`  untracked
///   `! <path>`  ignored
///
/// Nonisolated because parsing is pure value-to-value work.
nonisolated enum StatusParser {

    static func parse(_ output: String) -> [GitFileChange] {
        var results: [GitFileChange] = []

        // Records are NUL-terminated; keep empty subsequences so a rename's
        // trailing origPath token is not silently dropped, then walk with an
        // index because type-2 records consume the following token too.
        var tokens = output.split(separator: "\0", omittingEmptySubsequences: false).map(String.init)
        if tokens.last == "" { tokens.removeLast() } // final NUL terminator

        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            index += 1
            guard let kind = token.first else { continue }

            switch kind {
            case "1":
                appendOrdinary(token, fieldsBeforePath: 8, into: &results)
            case "2":
                appendOrdinary(token, fieldsBeforePath: 9, into: &results)
                index += 1 // skip the rename/copy origPath token
            case "u":
                let path = pathAfterFields(token, fieldsBeforePath: 10)
                if !path.isEmpty {
                    results.append(GitFileChange(path: path, status: .conflicted, isStaged: false))
                }
            case "?":
                let path = String(token.dropFirst(2)) // strip "? "
                if !path.isEmpty {
                    results.append(GitFileChange(path: path, status: .untracked, isStaged: false))
                }
            default:
                continue // "!" ignored, "#" headers, anything unexpected
            }
        }

        return results
    }

    /// Emits a staged and/or unstaged change for a type-1 or type-2 entry.
    /// `fieldsBeforePath` is the count of space-separated fields ahead of the path
    /// (8 for `1`, 9 for `2`). Both sides of the two-char `XY` status are honored,
    /// so a file staged *and* modified in the working tree yields two entries,
    /// matching how the changes list groups staged vs unstaged.
    private static func appendOrdinary(
        _ token: String,
        fieldsBeforePath: Int,
        into results: inout [GitFileChange]
    ) {
        let head = token.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard head.count > 1, head[1].count == 2 else { return }
        let xy = head[1]
        let indexStatus = xy[xy.startIndex]
        let workTreeStatus = xy[xy.index(after: xy.startIndex)]

        let path = pathAfterFields(token, fieldsBeforePath: fieldsBeforePath)
        guard !path.isEmpty else { return }

        if indexStatus != "." {
            results.append(GitFileChange(path: path, status: fileStatus(indexStatus), isStaged: true))
        }
        if workTreeStatus != "." {
            results.append(GitFileChange(path: path, status: fileStatus(workTreeStatus), isStaged: false))
        }
    }

    /// Returns everything after `fieldsBeforePath` single-space-separated fields,
    /// verbatim, so spaces inside the path itself are preserved.
    private static func pathAfterFields(_ token: String, fieldsBeforePath: Int) -> String {
        var idx = token.startIndex
        var seenSpaces = 0
        while seenSpaces < fieldsBeforePath, idx < token.endIndex {
            if token[idx] == " " { seenSpaces += 1 }
            idx = token.index(after: idx)
        }
        return String(token[idx...])
    }

    private static func fileStatus(_ char: Character) -> GitFileChange.FileStatus {
        switch char {
        case "M", "T": return .modified   // modified or typechange
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .added           // a copy introduces a new path
        default: return .modified
        }
    }
}
