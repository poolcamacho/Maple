# Maple

[![CI](https://github.com/poolcamacho/Maple/actions/workflows/ci.yml/badge.svg)](https://github.com/poolcamacho/Maple/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/github/license/poolcamacho/Maple)](LICENSE)
[![GitHub Sponsors](https://img.shields.io/github/sponsors/poolcamacho?label=Sponsor&logo=GitHub)](https://github.com/sponsors/poolcamacho)

A **free, fast, native** macOS Git client built with SwiftUI. Inspired by [GitExtensions](https://gitextensions.github.io/), designed to feel at home on macOS.

## Why

Most Git GUIs on macOS are either Electron-based, subscription-locked, or try to oversimplify Git. Maple aims to be a **free, fast, native** alternative that respects the full power of Git without hiding it behind abstractions.

## Goals

- **Native macOS experience** — built entirely in SwiftUI, no web views, no Electron
- **Full Git visibility** — commit graph, diff viewer, staging area, branch management, all in one window
- **Responsive layout** — adapts from wide desktop monitors to compact laptop windows without losing panels
- **Power-user friendly** — expose the operations that matter: interactive staging, stash, rebase, merge, cherry-pick
- **Fast** — talk directly to `git` CLI, no intermediate layers or daemons

## Current State

Maple is a functional Git client that talks directly to the `git` CLI via `Process`:

- **Open any local repo** via folder picker, with git validation
- **Sidebar** with repository list, local/remote branches, refresh button
- **Toolbar** with Pull, Push, Fetch, Stash, Branch actions + search field
- **Four main tabs**:
  - **Changes** — real `git status` with staged/unstaged files, per-file stage/unstage via `git add`/`git reset`, commit with message editor
  - **History** — real `git log --all` with graph nodes, branch tags, author, date, SHA. Select a commit to see its diff below
  - **Branches** — local and remote branches, checkout (including remote → local tracking), create, delete via context menu or detail panel
  - **Stashes** — `git stash list` with apply, pop, drop actions per entry
- **Diff viewer** — real `git diff` output parsed with line numbers, addition/deletion coloring, hunk headers
- **Auto-refresh** — FSEvents watcher on `.git/` triggers automatic UI refresh on external changes
- **Adaptive layout** — toolbar, columns, and panels collapse gracefully at smaller window sizes

### Architecture

```
Models/     — Pure data (AppState, GitModels, StashModels)
Services/   — GitService (CLI execution), GitCoordinator (orchestration),
              GitCommands/BranchOps/StashOps (extensions), FileWatcher
Views/      — One file per view, no business logic
Utils/      — FolderPicker, DateExtensions
```

## Roadmap

### Done

- [x] Git CLI integration via `Process`
- [x] Repository open with validation
- [x] Live `git status` / `git log` / `git diff` parsing
- [x] Commit, push, pull, fetch operations
- [x] Branch create, checkout, delete, rename
- [x] Stash management (save, pop, apply, drop)
- [x] Auto-refresh via FSEvents
- [x] Responsive layout with adaptive breakpoints
- [x] Separated architecture (Models / Services / Views / Utils)
- [x] Blame view (toggle in Changes tab, shows author/hash/date per line)
- [x] Commit graph with real branch topology (lane assignment, curved edges per parent)
- [x] Merge and rebase with conflict resolution UI (operation banner, abort/continue, per-file use ours/theirs)

### Next

- [ ] Interactive staging (stage individual hunks/lines)
- [ ] Tag management (create, list, delete)
- [ ] Search filtering (commits, files)
- [ ] Clone from URL
- [ ] Remote management (add, remove, configure)
- [ ] Keyboard shortcuts (Cmd+S stage, Cmd+Enter commit, etc.)
- [ ] Persist open repositories between sessions
- [ ] Settings and preferences

## Requirements

- macOS 14.0+ (Apple Silicon recommended, Intel supported)
- Xcode 15+
- Git installed (ships with Xcode Command Line Tools)

## Build

```bash
git clone https://github.com/poolcamacho/Maple.git
cd Maple
open Maple.xcodeproj
```

Build and run from Xcode (Cmd+R).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for community expectations. Report security issues via the process in [SECURITY.md](SECURITY.md).

## Sponsor

Maple is developed in the open on nights and weekends. If it saves you time, consider [sponsoring on GitHub](https://github.com/sponsors/poolcamacho) — it keeps the project free and actively maintained.

## License

[MIT](LICENSE)
