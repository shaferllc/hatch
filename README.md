# Hatch

*hatch — the opening in a ship's deck that gets you below in one step.*

Hatch is a menu-bar file browser in the spirit of FilePop: press one hotkey
and a Spotlight-style panel drops down with your folders laid out in miller
columns. Type a few letters, arrow into the folder you want, hit Return —
you're there. No Finder window, no docking, no waiting.

## Features

- **⌥⌘F anywhere** (or click the menu bar icon) opens the panel; Esc or
  clicking away closes it. The panel never steals your app's focus — it's a
  non-activating floating panel.
- **Miller columns** starting from Home, Desktop, Documents, Downloads, and
  iCloud Drive (when present), plus any extra roots you add.
- **Type to filter** the current column — prefix matches first, then
  substring, then fuzzy subsequence. Delete edits the filter, Esc clears it.
- **Keyboard-first**: ↑/↓ move, → descends into a folder, ← backs out,
  Return opens with the default app, ⌘Return reveals in Finder.
- **Space peeks** the selection with Quick Look.
- **⌘C copies** the selected file to the pasteboard; **drag any row** out of
  the panel to drop the file wherever you like.
- **⌘D pins** the selected folder to the favorites strip at the top of the
  panel; pins persist and are one click away.
- **Recents**: the last 10 things you opened through Hatch show up in the
  first column.
- **⌘. toggles hidden files** live; the default is a setting.
- Real file icons, folder child counts on rows, and a footer with size and
  modified date for the selection.
- Fast: directories are listed lazily per column, sorted folders-first;
  child counts are computed off the main thread.

## Build

```
./make-app.sh
```

Builds a release binary, generates the icon, assembles `Hatch.app`, installs
it to `/Applications`, and launches it. Hatch is a menu-bar-only app
(`LSUIElement`) — look for the three-column icon in the status bar.

## Permissions

None. The global hotkey uses Carbon's `RegisterEventHotKey`, which needs no
Accessibility access, and Hatch only reads the folders you browse.

## Not yet

- Custom hotkey recording (the hotkey is fixed at ⌥⌘F for now).
- File operations (rename, move, delete, new folder).
- Multi-selection.
