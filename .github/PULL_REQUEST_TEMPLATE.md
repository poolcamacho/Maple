## Summary

<!-- What does this PR change, and why? Link any related issues. -->

## Screenshots / recordings

<!-- Required for anything that changes the UI. Drag screenshots or .mov files here. -->

## Test plan

- [ ] Builds cleanly (`xcodebuild build` or `Cmd+B` in Xcode)
- [ ] `xcodebuild analyze` has no new warnings
- [ ] `swiftlint --strict` passes
- [ ] Manually verified the change on a real repository

## Checklist

- [ ] Follows existing architecture (Models / Services / Views / Utils)
- [ ] No business logic added inside a `View`
- [ ] Async git work goes through `GitCoordinator`
- [ ] README or roadmap updated if user-visible behaviour changed
