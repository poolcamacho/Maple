//
//  FileWatcher.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation
import Observation

/// Watches a repository's git directories and fires `onChange` on the main actor
/// (debounced) when refs, HEAD or the index change.
///
/// Callers pass resolved paths (`git rev-parse --absolute-git-dir` and
/// `--git-common-dir`) so this works for worktrees and submodules, where `.git`
/// is a file and refs live in a shared common dir separate from this checkout's
/// git dir. HEAD and the index are per-worktree (git dir); refs and packed-refs
/// are shared (common dir).
///
/// DispatchSource delivers its event handlers on a background queue, so all of
/// the watching machinery lives in a `nonisolated` `Engine` synchronized on a
/// private serial queue. Only the final notification hops back to the main actor.
@MainActor
@Observable
final class FileWatcher {

    /// Called on the main actor (debounced) when a watched path changes.
    var onChange: (() -> Void)?

    private let engine = Engine()

    /// Watch a repository given its resolved git dir and common dir.
    func watch(gitDir: String, commonDir: String) {
        engine.watch(gitDir: gitDir, commonDir: commonDir) { [weak self] in
            self?.onChange?()
        }
    }

    func stop() {
        engine.stop()
    }

    deinit {
        engine.stop()
    }
}

private extension FileWatcher {

    /// Owns the DispatchSource machinery off the main actor. `@unchecked Sendable`
    /// is sound because every access to the mutable state below is funneled
    /// through the private serial `queue`.
    nonisolated final class Engine: @unchecked Sendable {

        private let queue = DispatchQueue(label: "dev.poolcamacho.maple.filewatcher")
        private var sources: [DispatchSourceFileSystemObject] = []
        private var fileDescriptors: [Int32] = []
        private var debounceWorkItem: DispatchWorkItem?
        private let debounceInterval: TimeInterval = 0.5

        func watch(gitDir: String, commonDir: String, notify: @escaping @MainActor () -> Void) {
            queue.async { [self] in start(gitDir: gitDir, commonDir: commonDir, notify: notify) }
        }

        func stop() {
            queue.async { [self] in reset() }
        }

        // MARK: - Queue-confined work

        private func start(gitDir: String, commonDir: String, notify: @escaping @MainActor () -> Void) {
            reset()

            // Refs and packed-refs are shared across worktrees (common dir); HEAD,
            // the index and operation-state files (MERGE_HEAD, rebase-*) are
            // per-worktree (git dir). Watching the git-dir directory itself catches
            // index replacement (git writes index.lock then renames) and the
            // transient state files appearing and disappearing.
            let refsDir = commonDir as NSString
            let stateDir = gitDir as NSString
            let candidates = [
                commonDir,
                refsDir.appendingPathComponent("refs"),
                refsDir.appendingPathComponent("refs/heads"),
                refsDir.appendingPathComponent("refs/remotes"),
                gitDir,
                stateDir.appendingPathComponent("index")
            ]

            // Dedupe: for a normal (non-worktree) repo gitDir == commonDir, so the
            // two sets overlap and we must not open two sources on the same path.
            var seen = Set<String>()
            for path in candidates where seen.insert(path).inserted {
                addSource(path: path, notify: notify)
            }
        }

        private func addSource(path: String, notify: @escaping @MainActor () -> Void) {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { return }
            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .link],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.handleEvent(notify: notify)
            }
            source.setCancelHandler {
                close(fd)
            }
            sources.append(source)
            source.resume()
        }

        private func reset() {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil

            for source in sources {
                source.cancel()
            }
            sources.removeAll()
            fileDescriptors.removeAll()
        }

        /// Runs on `queue`. Coalesces bursts of filesystem events, then hops to the
        /// main actor once things settle for `debounceInterval`.
        private func handleEvent(notify: @escaping @MainActor () -> Void) {
            debounceWorkItem?.cancel()

            let work = DispatchWorkItem {
                Task { @MainActor in notify() }
            }
            debounceWorkItem = work

            queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
        }
    }
}
