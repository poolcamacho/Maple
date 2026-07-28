//
//  FileWatcher.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation
import Observation

/// Watches key files inside a repo's `.git` directory and fires `onChange` on the
/// main actor (debounced) when they change.
///
/// DispatchSource delivers its event handlers on a background queue, so all of the
/// watching machinery lives in a `nonisolated` `Engine` synchronized on a private
/// serial queue. Only the final `onChange` notification hops back to the main
/// actor. Letting the handlers run on the main actor (the default under
/// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) makes libdispatch abort with a queue
/// assertion the moment an event fires off the main queue.
@MainActor
@Observable
final class FileWatcher {

    /// Called on the main actor (debounced) when a watched path changes.
    var onChange: (() -> Void)?

    private let engine = Engine()

    /// Watch key paths inside a git repo for changes.
    func watch(directory: String) {
        engine.watch(directory: directory) { [weak self] in
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

        func watch(directory: String, notify: @escaping @MainActor () -> Void) {
            queue.async { [self] in start(directory: directory, notify: notify) }
        }

        func stop() {
            queue.async { [self] in reset() }
        }

        // MARK: - Queue-confined work

        private func start(directory: String, notify: @escaping @MainActor () -> Void) {
            reset()

            let gitDir = (directory as NSString).appendingPathComponent(".git")
            let paths = [
                gitDir,
                (gitDir as NSString).appendingPathComponent("refs"),
                (gitDir as NSString).appendingPathComponent("refs/heads"),
                (gitDir as NSString).appendingPathComponent("refs/remotes"),
            ]

            for path in paths {
                addSource(path: path, eventMask: [.write, .rename, .delete, .link], notify: notify)
            }

            // Stage/unstage writes .git/index without touching .git/refs, so we
            // watch it directly to refresh the changes list.
            let indexPath = (gitDir as NSString).appendingPathComponent("index")
            addSource(path: indexPath, eventMask: [.write, .rename], notify: notify)
        }

        private func addSource(
            path: String,
            eventMask: DispatchSource.FileSystemEvent,
            notify: @escaping @MainActor () -> Void
        ) {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { return }
            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: eventMask,
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
