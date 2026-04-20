//
//  FileWatcher.swift
//  Maple
//
//  Created by Pool Camacho on 4/13/26.
//

import Foundation
import Observation

@Observable
final class FileWatcher {

    /// Callback fired on the main actor when the watched directory changes.
    var onChange: (() -> Void)?

    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.5

    /// Watch key paths inside a git repo for changes.
    func watch(directory: String) {
        stop()

        let gitDir = (directory as NSString).appendingPathComponent(".git")
        let paths = [
            gitDir,
            (gitDir as NSString).appendingPathComponent("refs"),
            (gitDir as NSString).appendingPathComponent("refs/heads"),
            (gitDir as NSString).appendingPathComponent("refs/remotes"),
        ]

        for path in paths {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            fileDescriptors.append(fd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .link],
                queue: DispatchQueue.global(qos: .utility)
            )

            source.setEventHandler { [weak self] in
                self?.handleEvent()
            }

            source.setCancelHandler {
                close(fd)
            }

            sources.append(source)
            source.resume()
        }

        // Stage/unstage writes .git/index without touching .git/refs, so we have
        // to watch it directly to refresh the changes list.
        let indexPath = (gitDir as NSString).appendingPathComponent("index")
        let indexFd = open(indexPath, O_EVTONLY)
        if indexFd >= 0 {
            fileDescriptors.append(indexFd)

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: indexFd,
                eventMask: [.write, .rename],
                queue: DispatchQueue.global(qos: .utility)
            )

            source.setEventHandler { [weak self] in
                self?.handleEvent()
            }

            source.setCancelHandler {
                close(indexFd)
            }

            sources.append(source)
            source.resume()
        }
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    private func handleEvent() {
        debounceWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let callback = self?.onChange else { return }
            DispatchQueue.main.async {
                callback()
            }
        }
        debounceWorkItem = work

        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + debounceInterval,
            execute: work
        )
    }

    isolated deinit {
        stop()
    }
}
