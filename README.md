# Raycast Scripts

Personal Raycast commands and small macOS automations.

## Included tools

### Gather Windows to Main Display

`apple/gather-windows-to-main-display.applescript` is a Raycast Script Command
that brings standard, visible windows from disconnected or secondary displays
back onto the main display.

It:

- ignores minimized and full-screen windows;
- skips Raycast and Raycast Beta windows;
- shrinks windows that are larger than the main display's visible area; and
- keeps moved windows inside the visible frame with 24 points of padding.

To install it, open **Raycast Settings → Extensions → Script Commands**, add
the repository's `apple` directory, and grant Raycast Accessibility permission
when macOS requests it. The script already has executable permissions.

### Clean Mode

`clean-mode/` is a local Raycast extension for cleaning a Mac. Running **Clean
Mode** places an opaque black overlay on every connected display and blocks
ordinary keyboard input. Mouse and trackpad input remain available so the mode
can be ended with the centered **Click to Exit** button.

The displays remain awake. Clean Mode has no menu-bar item or persistent daemon;
its native process exists only while cleaning mode is active.

## Clean Mode setup

Clean Mode requires Node.js 22.14 or newer. The repository pins the Node 22
release line in `clean-mode/.node-version` and declares the supported range in
`clean-mode/package.json`.

```sh
cd clean-mode
n auto # or select Node 22 with another version manager
npm ci
npm run dev
```

`npm run dev` targets the installed Raycast v2 Beta channel. After the first
successful build, search for **Clean Mode** in Raycast. See
`clean-mode/README.md` for implementation details and limitations.

## Validation

From `clean-mode/`:

```sh
npm run lint
npm run build
```

## License

Unless otherwise noted, this repository is available under the MIT License.
See `LICENSE` and `clean-mode/THIRD_PARTY_NOTICES.md`.
