# Security Policy

## Reporting a vulnerability

If you discover a security issue in Maple, **please do not open a public GitHub issue**. Instead, use GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/poolcamacho/Maple/security) of this repository.
2. Click **Report a vulnerability**.
3. Fill in the form with enough detail to reproduce the issue.

You'll receive an acknowledgement within **7 days**. A fix is typically shipped within **30 days** of confirmation, depending on severity. Critical issues (arbitrary code execution, credential exposure, data loss) are triaged first.

Maple runs `git` on the user's local machine via `Process` with sandboxing disabled. Reports involving how Maple invokes `git`, parses its output, or handles repository paths, credentials, and file watchers are all in scope.

## Supported versions

Only the latest release on `master` is supported. Please upgrade before reporting.
