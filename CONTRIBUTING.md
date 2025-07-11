# Contributing to **BitTwister**

Thank you for taking the time to contribute! We welcome bug reports, feature requests, documentation fixes and pull‑requests. This guide explains how to create Issues and PRs while keeping the code base consistent and maintainable.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Prerequisites](#prerequisites)
3. [Issue Guidelines](#issue-guidelines)
4. [Pull‑Request Workflow](#pull-request-workflow)
5. [Branching & Commit Style](#branching--commit-style)
6. [Coding Standards](#coding-standards)
7. [Adding a Corruption or Recovery Strategy](#adding-a-corruption-or-recovery-strategy)
8. [Localization](#localization)
9. [Testing](#testing)
10. [Release Process](#release-process)

---

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/) v2.1. By participating you agree to abide by its terms. Violations may lead to removal of contribution privileges.

---

## Prerequisites

| Tool         | Version                                       |
| ------------ | --------------------------------------------- |
| **macOS**    | 13 Ventura or newer                           |
| **Xcode**    | 15 or newer (Swift 5.9)                       |
| **Homebrew** | Latest—optional for installing `swift-format` |

```bash
brew install swift-format   # optional but recommended
```

---

## Issue Guidelines

1. **Search before opening** to avoid duplicates.
2. Use a clear title, e.g. `feat: add RAR header repair` or `bug: crash when flipping >2 GiB files`.
3. Provide reproduction steps, expected vs. actual behaviour and attach a log (`~/Library/Containers/com.dazi.BitTwister/Logs/latest.log`) if possible.
4. Tag your Issue (`bug`, `feature`, `docs`) or let a maintainer triage it.

---

## Pull‑Request Workflow

```text
fork → clone → create feature branch → code + tests → run formatter → commit → push → PR
```

1. **Fork** the repo and create a topic branch, e.g. `git checkout -b feat/zip-header-repair`.
2. Follow the [Coding Standards](#coding-standards).
3. **Run tests** (`⌘U` in Xcode or `swift test`).
4. **Format** code before committing: `swift-format -m format -r Sources`.
5. Write a concise PR description and reference any Issues (`Fixes #42`).
6. Ensure CI passes before requesting review.

---

## Branching & Commit Style

* `main` — protected, always release‑ready.
* `dev`   — integration branch (maintainers only).
* `feat/*`, `fix/*`, `docs/*` for topic branches created by contributors.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): summary
```

Example: `feat(recovery): add PDF magic repair`.

---

## Coding Standards

* SwiftUI for UI; prefer lightweight state containers (`@Observable`, `@State`) over heavy objects.
* Use explicit access modifiers (`private`, `internal`).
* Localised strings must be added via the `loc("Chinese", "English", language)` helper.
* Functions should be ≤ 80 lines; refactor helpers into extensions.
* Format using **swift‑format** default rules.

---

## Adding a Corruption or Recovery Strategy

1. Create a file under `Sources/Strategies/`, e.g. `RARHeaderRepair.swift`.
2. Conform to the protocol:

```swift
protocol Strategy {
    static var id: String { get }
    func apply(to data: inout Data) throws
}
```

3. Register the strategy in the `CorruptionMethod` or `RecoveryStrategy` enum.
4. Add unit tests under `Tests/StrategyTests/`.
5. Update the README tables if applicable.

---

## Localization

All UI strings must be provided in both Simplified Chinese and English using the `loc` helper:

```swift
Text(loc("保留原文件", "Keep original", language))
```

---

## Testing

* Use **XCTest**.
* Target ≥ 80 % coverage for new code.
* Heavy file‑I/O tests belong in `Tests/Integration/` and should be guarded with `#if !CI` to skip on CI runners.

---

## Release Process

1. Merge PRs, bump the version in `aboutTab` and `Info.plist`.
2. Tag: `git tag vX.Y.Z && git push --tags`.
3. CI produces a notarised zip and uploads it to GitHub Releases.
4. Update `CHANGELOG.md` and close the milestone.

---

Happy hacking! 🎉

— BitTwister Team
