# ClipStack

Native macOS clipboard history — last 50 text copies, categorized
(🔗 links, ✉️ emails, 📞 phone numbers, 📝 other text). No third-party
anything: builds with the Swift toolchain from Xcode Command Line Tools.

## Use

- **⌘⇧V** anywhere → history menu pops at the cursor.
- Or click the 📋 icon in the menu bar.
- Pick an entry → it's back on your clipboard; paste with ⌘V.
- Passwords copied from password managers are never recorded.
- History (50 newest text copies) survives restarts:
  `~/Library/Application Support/ClipStack/history.json`.

## Build & install

    ./make-app.sh    # checks + release build + install to ~/Applications

Development: `swift build`, `swift run ClipStackChecks` (no `swift test`
here — Command Line Tools don't ship a test framework).

Spec: `docs/superpowers/specs/2026-07-14-clipboard-history-design.md`.
