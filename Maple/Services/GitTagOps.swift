//
//  GitTagOps.swift
//  Maple
//
//  Created by Pool Camacho on 7/28/26.
//

import Foundation

extension GitService {

    func tags(in directory: String) async throws -> [GitTag] {
        let separator = "\t"
        let format = ["%(refname:short)", "%(objectname:short)", "%(contents:subject)"]
            .joined(separator: separator)
        let output = try await run(
            ["for-each-ref", "--sort=-creatordate", "refs/tags", "--format=\(format)"],
            in: directory
        )

        var result: [GitTag] = []
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: separator)
            guard let name = parts.first, !name.isEmpty else { continue }
            result.append(GitTag(
                name: name,
                targetShortSHA: parts.count > 1 ? parts[1] : "",
                subject: parts.count > 2 ? parts[2] : ""
            ))
        }
        return result
    }

    /// Creates a lightweight tag, or an annotated one when `message` is non-empty.
    func createTag(name: String, message: String?, in directory: String) async throws {
        var args = ["tag"]
        if let message, !message.isEmpty {
            args.append(contentsOf: ["-a", name, "-m", message])
        } else {
            args.append(name)
        }
        _ = try await run(args, in: directory)
    }

    func deleteTag(name: String, in directory: String) async throws {
        _ = try await run(["tag", "-d", name], in: directory)
    }
}
