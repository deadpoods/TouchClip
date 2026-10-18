# Testing TouchClip

On a Mac with Swift 6 and Apple's developer tools:

```sh
zsh build.sh
zsh test.sh
```

The suite runs **40 checks** against a temporary named NSPasteboard and the app's AppKit controls. It does not read or overwrite the general system clipboard.

| Area | Coverage |
| --- | --- |
| Text | Unicode, whitespace, blank input, 64 KiB byte boundary |
| History | Deduplication, promotion, 20-entry eviction, stale selections |
| Capture | New copies, concealed/transient/generated markers, non-text data, oversized text |
| Controls | Pause/resume, clear without recapture, native button actions |
| Restore | Exact UTF-8 text on the pasteboard and an AppKit text view accepting it |
| Touch Bar | NSTouchBar construction, three entries per page, remaining-page selection |

The suite briefly opens a test window. Optional `zsh test.sh --capture` also captures the window, adds one screenshot check, and saves `docs/test-window.png`. This developer check may need screen-capture permission. It is not part of the installed app.

## Manual end-to-end check

1. Launch TouchClip. In a scratch document, copy `TouchClip first`, wait a second, then copy `TouchClip second` and wait again.
2. Open its menu bar icon. Confirm both entries appear in the window and, with hardware and App Controls mode available, on the Touch Bar.
3. Tap **TouchClip first** on the Touch Bar. In the scratch document press **Command-V**. It should paste the older selected text.
4. Try an onscreen history button too. Both selection methods must restore the same original text.
5. Pause, copy another value, then resume. The paused value should be absent.
6. Clear history. The list should empty, while Command-V still pastes the current system clipboard.
7. Quit and relaunch. History should start empty. Closing only the window should keep the menu bar app running.

If macOS denies clipboard access, TouchClip should remain usable without crashing or requesting unrelated permissions. Allow clipboard access in System Settings, then copy new text. If Touch Bar controls are hidden, check Keyboard → Touch Bar Settings → App Controls.

## Observed verification

Compiled, locally signed, installed, and launched on a **MacBookPro16,2** (Intel, Touch Bar), **macOS 26.6.2**, **Swift 6.3.3**. All 40 functional checks and the optional screenshot check passed. The native window was visually inspected. A person using that Mac confirmed entries in both interfaces and that tapping an older Touch Bar entry followed by Command-V pasted the selected text correctly.

Automated tests call public button actions; they do not simulate physical Touch Bar taps. Minimum-version compatibility and Apple silicon build targets do not mean every supported configuration was physically tested. Denial guidance follows the installed Apple SDK; clipboard permission was not toggled during that initial verification.
