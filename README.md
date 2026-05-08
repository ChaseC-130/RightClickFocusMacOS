# RightClickFocus

RightClickFocus is a tiny macOS menu-bar utility for macOS Tahoe-style desktop use.
When you right-click a background window, it tries to focus and raise that window
before the contextual menu opens.

## Build

```sh
./scripts/build-app.sh
```

The packaged app is written to:

```text
build/RightClickFocus.app
```

To create a distributable zip:

```sh
./scripts/package-release.sh
```

The release zip, DMG, and checksums are written to `build/`.

Local builds are ad-hoc signed by default so anyone can compile the project
without Apple Developer credentials. Ad-hoc builds may require granting macOS
privacy permissions again after rebuilding.

Official release builds are signed separately with the maintainer's Developer ID
Application certificate and notarized before upload. Private certificates,
profiles, notary credentials, and Apple account secrets are not stored in this
repository.

To create a notarized public release, first store notary credentials locally with
`xcrun notarytool store-credentials`, then run:

```sh
./scripts/notarize-release.sh
./scripts/publish-release.sh
```

## Run

For local development, open `build/RightClickFocus.app`. It runs quietly with a
Dock icon and menu-bar item. Click the Dock icon or choose `Open
RightClickFocus` from the menu-bar item to open the status window.

For normal installation, download the release DMG, open it, drag
`RightClickFocus.app` to Applications, then open it from Applications.

The app window and menu have toggles for `Focus on Right-Click` and `Launch at
Login`, plus appearance toggles for showing the Dock icon and menu-bar item. At
least one of the Dock icon or menu-bar item is shown by default, but both can be
hidden. If both are hidden, open `RightClickFocus.app` from Applications,
Spotlight, or Finder to show the status window again. Launch at Login writes a
user LaunchAgent at
`~/Library/LaunchAgents/com.chasecargill.RightClickFocus.plist`; if you move the
app, toggle Launch at Login off and on again so the saved path is updated. Login
launches run quietly and do not open the status window by default.

If the app is launched outside `/Applications` or `~/Applications`, the status
window prompts you to use the DMG installer window or otherwise move
`RightClickFocus.app` into Applications and reopen it from there. Running from
Applications keeps privacy permissions and Launch at Login pointed at the
installed copy.

You can also control Launch at Login from Terminal:

```sh
./scripts/enable-launch-at-login.sh
./scripts/disable-launch-at-login.sh
```

On first launch, macOS needs privacy permissions before global right-click capture
and Accessibility window focusing can work. Use `Request Permissions` in the app
window or menu:

1. Grant `RightClickFocus` permission in System Settings > Privacy & Security > Accessibility.
2. Grant `RightClickFocus` permission in System Settings > Privacy & Security > Input Monitoring.
3. Relaunch the app, or choose `Permissions` from the menu-bar item.

The app window and menu-bar item also have shortcuts to open both privacy panes.
If macOS does not show the Input Monitoring prompt, open Input Monitoring
manually, click `+`, add `RightClickFocus.app` from Applications, then quit and
reopen the app. The app window has a `Reveal App` button to select the current
bundle in Finder for this manual step.

macOS may show the Input Monitoring prompt only once for a given app identity. If
the prompt has already been dismissed or a stale privacy entry exists, choosing
`Request Input Monitoring / Open Settings` opens the Settings pane instead of
showing another prompt.

If Settings shows `RightClickFocus` as enabled but the app still reports missing
permissions, use `Reset Permissions` in the app window, then quit and reopen the
app. You can also reset stale TCC entries from Terminal and grant permissions to
the current bundle:

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
app name macOS reported under the right-click.

## GitHub Releases

Use the local notarized release scripts for public downloads:

```sh
./scripts/notarize-release.sh
./scripts/publish-release.sh
```

The notarized release script creates both a zip and a DMG. The DMG is the primary
user-facing download because it presents the standard macOS drag-to-Applications
install window.

The GitHub Actions release workflow remains available for manual ad-hoc test
builds, but public releases should be Developer ID signed and notarized locally.

## Notes

- The app uses a global `CGEvent` tap for right-clicks and Accessibility APIs to find
  and raise the window under the pointer.
- Some apps use custom or restricted Accessibility behavior, so individual windows may
  not always raise perfectly.
- If you rebuild the app after granting permissions, macOS may ask again because the
  executable changed.
