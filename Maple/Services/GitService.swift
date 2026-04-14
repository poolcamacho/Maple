//
//  GitService.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation

actor GitService {

    // MARK: - Locate git binary

    private static let gitPath: String = {
        let candidates = ["/usr/bin/git", "/usr/local/bin/git", "/opt/homebrew/bin/git"]
        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return path
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "which git"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result.isEmpty ? "/usr/bin/git" : result
    }()

    // MARK: - Run git command

    private static let defaultTimeout: TimeInterval = 30

    func run(_ arguments: [String], in directory: String, timeout: TimeInterval = defaultTimeout) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: Self.gitPath) else {
            throw GitError.gitNotFound(path: Self.gitPath)
        }

        let process = makeProcess(arguments: arguments, directory: directory)
        let stdout = Pipe(); process.standardOutput = stdout
        let stderr = Pipe(); process.standardError = stderr
        let stdinFD = attachDevNullStdin(to: process)

        do {
            try process.run()
        } catch {
            let cmd = arguments.joined(separator: " ")
            logLaunchFailure(command: cmd, directory: directory, error: error)
            if stdinFD >= 0 { close(stdinFD) }
            let nsError = error as NSError
            let detail = "\(nsError.domain) code=\(nsError.code) — \(nsError.localizedDescription)"
            throw GitError.processLaunchFailed(underlying: "git \(cmd): \(detail)")
        }

        let completed = await waitForProcess(process, timeout: timeout)

        // Always drain the pipes, even on timeout, so their file descriptors
        // aren't held open by the background read tasks.
        let (outData, errData) = await drainAndClose(stdout: stdout, stderr: stderr)

        guard completed else {
            throw GitError.timedOut(command: arguments.joined(separator: " "), seconds: Int(timeout))
        }

        if process.terminationStatus != 0 {
            let errOutput = String(data: errData, encoding: .utf8) ?? ""
            throw GitError.commandFailed(
                command: arguments.joined(separator: " "),
                exitCode: process.terminationStatus,
                message: errOutput
            )
        }

        return String(data: outData, encoding: .utf8) ?? ""
    }

    // MARK: - Run helpers

    private func makeProcess(arguments: [String], directory: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        var env = ProcessInfo.processInfo.environment
        env["LC_ALL"] = "C"
        env["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = env

        return process
    }

    /// Fresh `/dev/null` for stdin per call. `FileHandle.nullDevice` is a shared
    /// singleton and, in practice, gets into bad states across many Process
    /// launches (we've seen NSPOSIXErrorDomain code 9 / EBADF from posix_spawn).
    /// Opening a new fd each time with closeOnDealloc means each child gets a
    /// clean, owned read-side that the runtime will close deterministically.
    /// Returns the fd (or -1 on open failure) so the caller can close it on
    /// launch errors where the `FileHandle` never takes ownership.
    private func attachDevNullStdin(to process: Process) -> Int32 {
        let devNullFD = open("/dev/null", O_RDONLY)
        if devNullFD >= 0 {
            process.standardInput = FileHandle(fileDescriptor: devNullFD, closeOnDealloc: true)
        }
        return devNullFD
    }

    private func waitForProcess(_ process: Process, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let deadline = DispatchTime.now() + timeout
                while process.isRunning {
                    if DispatchTime.now() >= deadline {
                        process.terminate()
                        continuation.resume(returning: false)
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
                continuation.resume(returning: true)
            }
        }
    }

    private func drainAndClose(stdout: Pipe, stderr: Pipe) async -> (Data, Data) {
        // Read pipes on background threads to avoid deadlocks
        // (pipes can fill their buffer and block the process)
        async let outRead = Task.detached {
            stdout.fileHandleForReading.readDataToEndOfFile()
        }.value
        async let errRead = Task.detached {
            stderr.fileHandleForReading.readDataToEndOfFile()
        }.value

        let outData = await outRead
        let errData = await errRead

        // Close the read ends explicitly so deinit ordering never delays cleanup.
        try? stdout.fileHandleForReading.close()
        try? stderr.fileHandleForReading.close()

        return (outData, errData)
    }

    private func logLaunchFailure(command: String, directory: String, error: Error) {
        let nsError = error as NSError
        let detail = "\(nsError.domain) code=\(nsError.code) — \(nsError.localizedDescription)"
        FileHandle.standardError.write(Data("[Maple] process.run() failed for `git \(command)` in \(directory): \(detail)\n".utf8))
    }

    // MARK: - Validate repository

    /// Returns nil if valid, or an error description if not
    func validateRepository(at path: String) async -> String? {
        // Fast pre-check before invoking git: .git may be a directory (regular
        // repos) or a file (worktrees/submodules), so we test existence, not dir-ness.
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return "Folder does not exist: \(path)"
        }
        let gitPath = (path as NSString).appendingPathComponent(".git")
        if !FileManager.default.fileExists(atPath: gitPath) {
            return "Not a git repository: no .git directory found in \(path). Pick the repo's root folder (the one that contains .git)."
        }

        do {
            let output = try await run(["rev-parse", "--is-inside-work-tree"], in: path)
            if output.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                return nil
            }
            return "Directory is not inside a git work tree."
        } catch let error as GitError {
            return error.errorDescription
        } catch {
            return error.localizedDescription
        }
    }

    func repositoryName(at path: String) async -> String {
        do {
            let output = try await run(["rev-parse", "--show-toplevel"], in: path)
            let topLevel = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(fileURLWithPath: topLevel).lastPathComponent
        } catch {
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    // MARK: - Current branch

    func currentBranch(in directory: String) async throws -> String {
        let output = try await run(["branch", "--show-current"], in: directory)
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if branch.isEmpty {
            // Detached HEAD: --show-current returns empty, fall back to short SHA.
            let sha = try await run(["rev-parse", "--short", "HEAD"], in: directory)
            return "(\(sha.trimmingCharacters(in: .whitespacesAndNewlines)))"
        }
        return branch
    }

    // MARK: - Branches

    func branches(in directory: String) async throws -> [GitBranch] {
        let output = try await run(["branch", "-a", "--no-color"], in: directory)
        var results: [GitBranch] = []

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let isCurrent = line.hasPrefix("* ")
            var name = line
                .replacingOccurrences(of: "* ", with: "")
                .trimmingCharacters(in: .whitespaces)

            if name.contains("->") { continue }

            let isRemote = name.hasPrefix("remotes/")
            if isRemote {
                name = String(name.dropFirst("remotes/".count))
            }

            results.append(GitBranch(name: name, isRemote: isRemote, isCurrent: isCurrent))
        }

        return results
    }

    // MARK: - Status (file changes)

    func status(in directory: String) async throws -> [GitFileChange] {
        let output = try await run(["status", "--porcelain=v1"], in: directory)
        var results: [GitFileChange] = []

        for line in output.components(separatedBy: "\n") where line.count >= 3 {
            let indexStatus = line[line.index(line.startIndex, offsetBy: 0)]
            let workTreeStatus = line[line.index(line.startIndex, offsetBy: 1)]
            let filePath = String(line[line.index(line.startIndex, offsetBy: 3)...])
                .trimmingCharacters(in: .whitespaces)
                // Porcelain encodes renames as "old -> new"; we only want the new path.
                .components(separatedBy: " -> ").last ?? ""

            if Self.isConflictCode(indexStatus, workTreeStatus) {
                results.append(GitFileChange(path: filePath, status: .conflicted, isStaged: false))
                continue
            }

            if indexStatus != " " && indexStatus != "?" {
                let status = Self.parseFileStatus(indexStatus)
                results.append(GitFileChange(path: filePath, status: status, isStaged: true))
            }

            if workTreeStatus != " " {
                if workTreeStatus == "?" {
                    results.append(GitFileChange(path: filePath, status: .untracked, isStaged: false))
                } else {
                    let status = Self.parseFileStatus(workTreeStatus)
                    results.append(GitFileChange(path: filePath, status: status, isStaged: false))
                }
            }
        }

        return results
    }

    private static func isConflictCode(_ x: Character, _ y: Character) -> Bool {
        if x == "U" || y == "U" { return true }
        if x == "A" && y == "A" { return true }
        if x == "D" && y == "D" { return true }
        return false
    }

    private static func parseFileStatus(_ char: Character) -> GitFileChange.FileStatus {
        switch char {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        default: return .modified
        }
    }

    // MARK: - Log (commit history)

    func log(in directory: String, maxCount: Int = 200) async throws -> [GitCommit] {
        // Custom separator (unlikely to appear in commit messages) lets us parse
        // fields safely even when subjects contain tabs/pipes/etc.
        // Fields: hash, shortHash, subject, author, unixTimestamp, parents, refNames.
        let separator = "<MAPLE_SEP>"
        let format = ["%H", "%h", "%s", "%an", "%at", "%P", "%D"].joined(separator: separator)
        let output = try await run(
            ["log", "--all", "--format=\(format)", "-\(maxCount)"],
            in: directory
        )

        var commits: [GitCommit] = []

        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: separator)
            guard parts.count >= 6 else { continue }

            let hash = parts[0]
            let shortHash = parts[1]
            let message = parts[2]
            let author = parts[3]
            let timestamp = TimeInterval(parts[4]) ?? 0
            let parents = parts[5].components(separatedBy: " ").filter { !$0.isEmpty }
            let refNames = parts.count > 6 ? parts[6] : ""

            let branch = Self.parseBranchFromRefs(refNames)

            commits.append(GitCommit(
                id: hash,
                shortID: shortHash,
                message: message,
                author: author,
                date: Date(timeIntervalSince1970: timestamp),
                branch: branch,
                parents: parents
            ))
        }

        return commits
    }

    private static func parseBranchFromRefs(_ refs: String) -> String? {
        guard !refs.isEmpty else { return nil }

        // "HEAD -> branch" always points at the checked-out branch; prefer it.
        if let headRange = refs.range(of: "HEAD -> ") {
            let afterHead = refs[headRange.upperBound...]
            let branchName = afterHead.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? ""
            if !branchName.isEmpty { return branchName }
        }

        let refList = refs.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for ref in refList {
            if ref == "HEAD" { continue }
            if ref.hasPrefix("tag:") { continue }
            return ref
        }

        return nil
    }

    // MARK: - Diff

    func diff(for filePath: String, staged: Bool, in directory: String) async throws -> [DiffLine] {
        var args = ["diff", "--no-color"]
        if staged {
            args.append("--cached")
        }
        args.append("--")
        args.append(filePath)

        let output = try await run(args, in: directory)
        return Self.parseDiff(output)
    }

    func diffForCommit(_ commitHash: String, in directory: String) async throws -> [DiffLine] {
        let output = try await run(
            ["show", "--no-color", "--format=", commitHash],
            in: directory
        )
        return Self.parseDiff(output)
    }

    /// `git diff` skips untracked files, so we synthesize an all-additions diff
    /// by reading the file directly.
    func diffForUntrackedFile(_ filePath: String, in directory: String) async throws -> [DiffLine] {
        let fullPath = (directory as NSString).appendingPathComponent(filePath)
        guard let data = FileManager.default.contents(atPath: fullPath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var lines: [DiffLine] = []
        lines.append(DiffLine(content: "new file: \(filePath)", type: .header, oldLineNumber: nil, newLineNumber: nil))

        for (index, line) in content.components(separatedBy: "\n").enumerated() {
            lines.append(DiffLine(
                content: line,
                type: .addition,
                oldLineNumber: nil,
                newLineNumber: index + 1
            ))
        }

        return lines
    }

    static func parseDiff(_ output: String) -> [DiffLine] {
        var lines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        for rawLine in output.components(separatedBy: "\n") {
            if rawLine.hasPrefix("@@") {
                // Hunk header format: "@@ -oldStart,oldCount +newStart,newCount @@"
                let numbers = rawLine.components(separatedBy: " ")
                if numbers.count >= 3 {
                    let newPart = numbers[2]
                    let oldPart = numbers[1]
                    newLine = Int(newPart.dropFirst().components(separatedBy: ",").first ?? "0") ?? 0
                    oldLine = Int(oldPart.dropFirst().components(separatedBy: ",").first ?? "0") ?? 0
                }
                lines.append(DiffLine(content: rawLine, type: .header, oldLineNumber: nil, newLineNumber: nil))
            } else if rawLine.hasPrefix("+") && !rawLine.hasPrefix("+++") {
                let content = String(rawLine.dropFirst())
                lines.append(DiffLine(content: content, type: .addition, oldLineNumber: nil, newLineNumber: newLine))
                newLine += 1
            } else if rawLine.hasPrefix("-") && !rawLine.hasPrefix("---") {
                let content = String(rawLine.dropFirst())
                lines.append(DiffLine(content: content, type: .deletion, oldLineNumber: oldLine, newLineNumber: nil))
                oldLine += 1
            } else if rawLine.hasPrefix(" ") {
                let content = String(rawLine.dropFirst())
                lines.append(DiffLine(content: content, type: .context, oldLineNumber: oldLine, newLineNumber: newLine))
                oldLine += 1
                newLine += 1
            }
            // Silently drop "diff --git", "index", "---", "+++" preamble lines.
        }

        return lines
    }

    // MARK: - Blame

    func blame(for filePath: String, in directory: String) async throws -> [BlameLine] {
        let output = try await run(["blame", "--porcelain", "--", filePath], in: directory)
        return Self.parseBlame(output)
    }

    static func parseBlame(_ output: String) -> [BlameLine] {
        struct CommitMeta {
            var author: String = ""
            var date: Date = Date()
            var summary: String = ""
        }

        var lines: [BlameLine] = []
        var metaCache: [String: CommitMeta] = [:]

        var currentHash = ""
        var currentFinalLine = 0
        var currentMeta = CommitMeta()

        for raw in output.components(separatedBy: "\n") {
            if raw.hasPrefix("\t") {
                let content = String(raw.dropFirst())
                lines.append(BlameLine(
                    lineNumber: currentFinalLine,
                    content: content,
                    commitHash: currentHash,
                    shortHash: String(currentHash.prefix(7)),
                    author: currentMeta.author,
                    date: currentMeta.date,
                    summary: currentMeta.summary
                ))
                continue
            }

            let parts = raw.components(separatedBy: " ")
            // Blame porcelain commit header: "<40-char hash> <origLine> <finalLine> [<numLines>]"
            if parts.count >= 3, parts[0].count == 40, Int(parts[2]) != nil {
                currentHash = parts[0]
                currentFinalLine = Int(parts[2]) ?? 0
                currentMeta = metaCache[currentHash] ?? CommitMeta()
            } else if raw.hasPrefix("author ") {
                currentMeta.author = String(raw.dropFirst("author ".count))
                metaCache[currentHash] = currentMeta
            } else if raw.hasPrefix("author-time ") {
                let ts = String(raw.dropFirst("author-time ".count))
                currentMeta.date = Date(timeIntervalSince1970: TimeInterval(ts) ?? 0)
                metaCache[currentHash] = currentMeta
            } else if raw.hasPrefix("summary ") {
                currentMeta.summary = String(raw.dropFirst("summary ".count))
                metaCache[currentHash] = currentMeta
            }
        }

        return lines
    }

    // MARK: - Stage / Unstage

    func stage(file: String, in directory: String) async throws {
        _ = try await run(["add", "--", file], in: directory)
    }

    func unstage(file: String, in directory: String) async throws {
        _ = try await run(["reset", "HEAD", "--", file], in: directory)
    }

    func stageAll(in directory: String) async throws {
        _ = try await run(["add", "-A"], in: directory)
    }

    func unstageAll(in directory: String) async throws {
        _ = try await run(["reset", "HEAD"], in: directory)
    }
}

// MARK: - Errors

enum GitError: LocalizedError {
    case commandFailed(command: String, exitCode: Int32, message: String)
    case notARepository
    case gitNotFound(path: String)
    case processLaunchFailed(underlying: String)
    case timedOut(command: String, seconds: Int)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let cmd, let code, let msg):
            return "git \(cmd) failed (\(code)): \(msg)"
        case .notARepository:
            return "Not a git repository"
        case .gitNotFound(let path):
            return "Git not found at \(path). Install Xcode Command Line Tools."
        case .processLaunchFailed(let msg):
            return "Failed to launch git: \(msg). App may need to be run without sandbox."
        case .timedOut(let cmd, let seconds):
            return "git \(cmd) timed out after \(seconds)s. Check your network or SSH config."
        }
    }
}
