# Clean Mode

A minimal local Raycast extension for cleaning a Mac:

1. Covers every connected display with an opaque black full-screen overlay.
2. Locks ordinary keyboard input indefinitely.
3. Keeps the mouse and trackpad available for the centered **Click to Exit** button.

The displays remain awake; this is a visual cleaning shield rather than display
sleep, so pressing keys cannot wake or unlock macOS.

## Usage

1. Open Raycast and run **Clean Mode**.
2. Wait for the black overlay to appear on every connected display.
3. Clean the displays and keyboard.
4. Click **Click to Exit** on any display to restore normal input.

Mouse and trackpad input intentionally remain enabled. Physical keyboard input,
including `Control + U`, is swallowed while the mode is active; the on-screen
button is the normal exit path.

## Installation and development

Raycast's current toolchain requires Node.js 22.14 or newer. The repository
pins the Node 22 release line in `.node-version` and declares the supported
range in `package.json`.

```sh
n auto # or select Node 22 with another version manager
npm ci
npm run dev
```

`npm run dev` targets the installed Raycast v2 Beta (`x`) channel. Keep this
process running while developing; Raycast reloads the local command when files
change. After the first successful development build, **Clean Mode** remains
imported in Raycast.

Validate changes before committing:

```sh
npm run lint
npm run build
```

## Implementation

The visual design follows One Switch's Screen Cleaning Mode: a near-empty black
screen, a centered cleaning symbol and title, a **Click to Exit** button, and a
bottom note that the keyboard is locked.

The multi-display window structure uses the native AppKit pattern demonstrated
by the MIT-licensed [StandLock](https://github.com/yagizdo/standlock): one
borderless `.screenSaver`-level window per `NSScreen`, joined to every Space.
The keyboard event-tap implementation is adapted from Raycast Store's
[Clean Keyboard](https://github.com/raycast/extensions/tree/main/extensions/clean-keyboard),
also MIT licensed. Everything runs through Raycast's supported `swift:` module
bridge; there is no UI automation, display sleep, menu-bar process, or daemon.
See `THIRD_PARTY_NOTICES.md` for attribution.

## Limitations

- Raycast must have Accessibility permission for keyboard interception.
- Trackpad and mouse input intentionally remain active so the exit button can be clicked.
- macOS may not expose Touch ID and some hardware-level special keys to an event tap.
- The displays stay powered on behind the opaque overlays; this command does not invoke display sleep.
