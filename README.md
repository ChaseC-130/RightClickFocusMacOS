# RightClickFocus

RightClickFocus is a tiny macOS menu-bar utility for macOS Tahoe-style desktop use:
when you right-click a background window, it tries to focus and raise that window
before the contextual menu opens.

It is especially useful for RuneLite/OSRS players who keep
RuneLite behind another active window, such as Chrome, and want a right-click on
the game window to bring RuneLite forward before opening the in-game menu.

## Build

```sh
./scripts/build-app.sh
```

The packaged app is written to:

```text
build/RightClickFocus.app
```

If an Apple Development signing identity is available, the build script uses it
so macOS privacy grants remain stable across rebuilds. Otherwise it falls back
to ad-hoc signing, which may require granting permissions again after rebuilding.

## Run

Open `build/RightClickFocus.app`. It runs as a menu-bar app with no Dock icon.

The menu has toggles for `Launch at Login` and `Show Menu Bar Icon`. Launch at
Login writes a user LaunchAgent at
`~/Library/LaunchAgents/com.chasecargill.RightClickFocus.plist`; if you move the
app, toggle Launch at Login off and on again so the saved path is updated.

You can also control Launch at Login from Terminal:

```sh
./scripts/enable-launch-at-login.sh
./scripts/disable-launch-at-login.sh
```

If you hide the menu bar icon and want it back later, run:

```sh
./scripts/show-menu-icon.sh
```

You can also hide it from Terminal:

```sh
./scripts/hide-menu-icon.sh
```

On first launch, macOS needs privacy permissions before global right-click capture
and Accessibility window focusing can work. The app explicitly requests both
permissions on startup:

1. Grant `RightClickFocus` permission in System Settings > Privacy & Security > Accessibility.
2. Grant `RightClickFocus` permission in System Settings > Privacy & Security > Input Monitoring.
3. Relaunch the app, or choose `Permissions` from the menu-bar item.

The menu-bar item also has shortcuts to open both privacy panes. If macOS does
not show the Input Monitoring prompt, use the menu shortcut to open Input
Monitoring manually, add `RightClickFocus`, then quit and reopen the app.

macOS may show the Input Monitoring prompt only once for a given app identity. If
the prompt has already been dismissed or a stale privacy entry exists, choosing
`Request Input Monitoring / Open Settings` opens the Settings pane instead of
showing another prompt.

If Settings shows `RightClickFocus` as enabled but the app still reports missing
permissions, reset stale TCC entries and grant permissions to the current bundle:

```sh
./scripts/reset-permissions.sh
open build/RightClickFocus.app
```

## Diagnose Permissions

To audit what macOS has granted to this exact app bundle:

```sh
./scripts/diagnose.sh
```

The script launches `RightClickFocus.app` through LaunchServices, writes a report,
and prints it. That matters because launching the executable directly from a shell
can be attributed differently by macOS privacy controls.

`Accessibility trusted` and `Input Monitoring preflight` should both say `yes`.
`Input Monitoring preflight` is the important signal for live right-click capture.
`Right-click event tap creatable` should also say `yes`; if it says `no`, the app
cannot even create the listener.

After a test click, open the menu-bar item and check `Last Target`. It shows the
app name macOS reported under the right-click, such as `RuneLite` or
`Google Chrome`.

## Notes

- The app uses a global `CGEvent` tap for right-clicks and Accessibility APIs to find
  and raise the window under the pointer.
- Some apps use custom or restricted Accessibility behavior, so individual windows may
  not always raise perfectly.
- If you rebuild the app after granting permissions, macOS may ask again because the
  executable changed.
