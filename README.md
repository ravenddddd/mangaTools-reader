# mangaTools Reader

An iOS reader for the manga galleries the [mangaTools](https://github.com/ravenddddd/mangaTools)
Stash plugin manages. It reads Stash's GraphQL API directly — there is no
server component and nothing is written back.

- **Shelf** — every gallery the plugin marked as manga, by cover, searchable by
  title, circle or tag.
- **Work** — the gallery's chapters, as the plugin stores them.
- **Reader** — one chapter, one page at a time, swiped horizontally, with pinch
  and double-tap zoom. The reading position is remembered per gallery.

## What it reads

| Data | Where it comes from |
|---|---|
| Which galleries | `plugin.mangaTools.manga` is set |
| Chapters | `plugin.mangaTools.chapters` (format v1 and v2) |
| Pages | Stash's images of the gallery, in path order (`sort: "path"`) |
| Titles | Stash's own fallback: title, else first file's name, else folder |

A chapter is a **set** of image ids, not a range: its pages are those images in
the gallery's path order. A gallery with no readable chapter field is one book
over the whole gallery. "Physical pages" (the plugin's file-id identity) is not
read — chapters are drawn from the deduplicated image list.

## Requirements

- iOS 17 or newer.
- Stash 0.31 or newer, reachable from the phone.
- The mangaTools plugin installed, with at least one gallery marked as manga.
- An API key if Stash requires authentication (Settings → Security).

## Install (sideloading)

The GitHub workflow produces an **unsigned** IPA:

1. Open the repository's **Actions → ipa → latest run** and download the
   `mangaToolsReader-unsigned-ipa` artifact.
2. Install it with [Sideloadly](https://sideloadly.io/) or
   [AltStore](https://altstore.io/) using your own Apple ID. A free Apple ID
   signs for 7 days at a time; a paid developer account signs for a year.

Unsigned builds are also what TrollStore can install where the system version
allows it.

There is no App Store release and no app icon yet.

## Build it yourself

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — no `.xcodeproj` is checked
in, so two machines cannot drift apart:

```bash
brew install xcodegen
xcodegen generate
open MangaToolsReader.xcodeproj
```

A signed build for your own device is the normal Xcode flow: pick a team, pick
`MangaToolsReader`, run. For CI, push — `.github/workflows/ipa.yml` builds on
`macos-15`, packages `Payload/MangaToolsReader.app` into an IPA and uploads it;
a `v*` tag also attaches it to a GitHub release.

### Codemagic

`codemagic.yaml` runs the same build on [Codemagic](https://codemagic.io)'s
Mac mini M2 — usually a much shorter wait than a GitHub-hosted macOS runner
(the free plan includes 500 build minutes a month, one build at a time).
Sign in with GitHub, add this repository, and Codemagic picks the workflow up;
builds start on every push, and the IPA is on the build's **Artifacts** tab.
Free-plan artifacts are kept for 30 days.

The first launch asks for the server address and the API key. The address is
kept in preferences, the key in the keychain.

## Configuration in Stash

Everything is read-only. The plugin's own settings decide what is marked and
what the chapters contain; this app only displays those.

## Limitations

- **Left-to-right paging only.** Manga is usually read right to left; a
  direction setting is not built yet.
- **No progress writeback.** The plugin's reader stores nothing, and this app
  keeps its position on the device only.
- **No offline downloads.** Pages are fetched as they are shown and cached in
  memory (240 images) for the session.
- Chapters come from the chapter field only; Stash's own chapter rows are not
  read.
- Single-page layout only: no spread, no column mode.

## Credits

The reading interaction — a horizontal pager with a zooming page underneath and
a chrome that a tap toggles — follows [stashy](https://github.com/1letzgo/stashy)
(MIT, © 2026 letzgo), a native Stash client for iOS/tvOS and Android. This app
is a much smaller thing built for one plugin's data; the code here is its own.

## License

MIT. See [LICENSE](LICENSE).
