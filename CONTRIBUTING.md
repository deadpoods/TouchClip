# Contributing to TouchClip

TouchClip is intentionally small: local plain-text clipboard history, native AppKit controls, and a supported Touch Bar workflow.

Use macOS 14 or later and a Swift 6 compiler supplied by Apple's Command Line Tools or Xcode.

```sh
zsh build.sh
zsh test.sh
open build/TouchClip.app
```

Tests use an isolated named pasteboard and synthetic text. They must never read or overwrite the general clipboard. Touch Bar hardware is optional for development; the onscreen history provides the same selection flow.

## Keep the app's promises

- Use public Apple APIs. Touch Bar controls appear while TouchClip is active.
- Keep history in memory. Do not add clipboard-content logging, analytics, networking, or sync.
- Preserve original text, bound history and entry sizes, and respect clipboard opt-out markers.
- Avoid broad privacy permissions. The user presses Command-V; TouchClip does not generate keystrokes.
- Keep dependencies and setup small. Explain a new dependency's concrete benefit.

For bugs, include your macOS version, CPU architecture, whether a Touch Bar is present, reproduction steps, and expected behavior. Use synthetic text and remove private clipboard content from screenshots and logs.

For pull requests, describe the resulting behavior and checks. Include a screenshot for UI changes, using example text, and follow the manual test in [docs/TESTING.md](docs/TESTING.md). State the hardware you actually tested; automated button actions do not prove physical Touch Bar behavior.
