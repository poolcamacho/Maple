# Contributing to Maple

Thanks for your interest in contributing to Maple.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Open `Maple.xcodeproj` in Xcode
4. Build and run (Cmd+R)

## Requirements

- macOS 14.0+
- Xcode 15+
- Git installed

## Development

- The app runs without sandbox to access `/usr/bin/git` and local repositories
- All git operations go through `GitService` (actor) via `Process`
- Business logic lives in `GitCoordinator`, views only call `state.coordinator.*`
- One view per file in `Views/`, pure UI with no business logic

## Pull Requests

- Keep PRs focused on a single feature or fix
- Follow existing code style (SwiftUI, no UIKit/AppKit unless necessary)
- Test with at least one real git repository before submitting

## Issues

Use GitHub Issues for bug reports and feature requests. Include:
- macOS version
- Steps to reproduce (for bugs)
- Screenshots if relevant
