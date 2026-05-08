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

## Run

Open `build/RightClickFocus.app`. It runs as a menu-bar app with no Dock icon.

On first launch, macOS needs privacy permissions before global right-click capture
and Accessibility window focusing can work. The app explicitly requests both
permissions on startup:

1. Grant `RightClickFocus` permission in System Settings > Privacy & Security > Accessibility.
2. Grant `RightClickFocus` permission in System Settings > Privacy & Security > Input Monitoring.
3. Relaunch the app, or choose `Permissions` from the menu-bar item.

The menu-bar item also has shortcuts to open both privacy panes. If macOS does
not show the Input Monitoring prompt, use the menu shortcut to open Input
Monitoring manually, add `RightClickFocus`, then quit and reopen the app.

After a test click, open the menu-bar item and check `Last Target`. If it says
`RuneLite`, the app detected the right window and the remaining problem is macOS
activation/raising. If it says `Google Chrome`, the click point is still landing
on Chrome according to the system window stack.

## Notes

- The app uses a global `CGEvent` tap for right-clicks and Accessibility APIs to find
  and raise the window under the pointer.
- Some apps use custom or restricted Accessibility behavior, so individual windows may
  not always raise perfectly.
- If you rebuild the app after granting permissions, macOS may ask again because the
  executable changed.
