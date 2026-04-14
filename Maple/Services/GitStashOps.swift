//
//  GitStashOps.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

extension GitService {

    // MARK: - Stash Save

    func stashSave(message: String?, includeUntracked: Bool = true, in directory: String) async throws {
        var args = ["stash", "push"]
        if includeUntracked {
            args.append("-u")
        }
        if let message, !message.isEmpty {
            args.append("-m")
            args.append(message)
        }
        _ = try await run(args, in: directory)
    }

    // MARK: - Stash Pop

    func stashPop(index: Int = 0, in directory: String) async throws {
        _ = try await run(["stash", "pop", "stash@{\(index)}"], in: directory)
    }

    // MARK: - Stash Apply

    func stashApply(index: Int = 0, in directory: String) async throws {
        _ = try await run(["stash", "apply", "stash@{\(index)}"], in: directory)
    }

    // MARK: - Stash Drop

    func stashDrop(index: Int, in directory: String) async throws {
        _ = try await run(["stash", "drop", "stash@{\(index)}"], in: directory)
    }

    // MARK: - Stash List

    func stashList(in directory: String) async throws -> [GitStashEntry] {
        let separator = "<SEP>"
        let output = try await run(
            ["stash", "list", "--format=%gd\(separator)%s\(separator)%cr"],
            in: directory
        )

        var entries: [GitStashEntry] = []

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: separator)
            guard parts.count >= 3 else { continue }

            let ref = parts[0]
            let message = parts[1]
            let relativeDate = parts[2]

            // Pull the integer index out of git's "stash@{N}" reference syntax.
            let indexString = ref
                .replacingOccurrences(of: "stash@{", with: "")
                .replacingOccurrences(of: "}", with: "")
            let index = Int(indexString) ?? 0

            entries.append(GitStashEntry(
                id: ref,
                index: index,
                message: message,
                relativeDate: relativeDate
            ))
        }

        return entries
    }
}
