# ClipStack

Native macOS clipboard history — last 50 text copies, categorized
(🔗 links, ✉️ emails, 📞 phone numbers, 📝 other text). No third-party
anything: builds with the Swift toolchain from Xcode Command Line Tools.

## Use

- **⌃⇧V** (Control-Shift-V) anywhere → history menu pops at the cursor.
  (Not ⌘⇧V — that's "Paste and Match Style" in many apps, and a global
  hotkey would steal it from all of them.)
- Or click the clipboard icon in the menu bar.
- Pick an entry (or press 1–5 while the menu is open) → it's back on your
  clipboard; paste with ⌘V. Hover an entry to see when it was copied and a
  preview of the full text (titles truncate at 50 characters).
- Hold **⌥ (option)** and click an entry to delete just that entry
  (the icon switches to a trash can while ⌥ is down).
- Hold **⇧ (shift)** and click an entry to pin it: pinned entries live in
  their own section at the top and are exempt from the size cap and expiry —
  good for snippets you paste all the time. ⇧-click again to unpin.
- Copies that password managers mark confidential (the standard
  `ConcealedType` pasteboard marker — 1Password, Bitwarden, etc.) are never
  recorded. A password copied from somewhere unmarked (e.g. a terminal) is
  recorded like any other text — use **Pause Capture** in the menu before
  handling secrets (the menu bar icon dims while paused; copies made during
  the pause are never recorded, even after resuming).
- History (50 newest text copies) survives restarts:
  `~/Library/Application Support/ClipStack/history.json` (owner-only perms).

## Settings

All optional, via `defaults write com.brucepan.clipstack …`; relaunch to apply.

    hotKeyCode -int 9          # Carbon key code (9 = V)
    hotKeyModifiers -int 4608  # ⌃⇧ (control 4096 + shift 512; cmd 256, option 2048)
    maxEntries -int 100        # history size (default 50)
    maxAgeDays -int 30         # auto-delete entries older than this (default 7; 0 = never)

## Build & install

    ./make-app.sh    # checks + release build + install to ~/Applications

Development: `swift build`, `swift run ClipStackChecks` (no `swift test`
here — Command Line Tools don't ship a test framework).
