# mockup_viewer

A phone viewer for disposable HTML mockups, with a comment box per screen.

The project keeps only its HTML files plus a small `mockups.json`. The viewer
page lives in this package. Reviewers open one URL on a phone or a laptop,
walk the screens, and leave comments. The designer reads one Markdown file.

Two packages:

| Package | What it is |
|---|---|
| `packages/mockup_viewer` | Pure Dart. The viewer page, the manifest parser, the file and comment logic, a shelf handler, and a CLI. |
| `packages/mockup_viewer_serverpod` | Mounts the viewer on a Serverpod web server with one call. |

## The viewer

- One phone at a time. Previous and next cross into the neighbour flow.
- Floating buttons on mobile (press and hold to drag them). A sidebar on
  desktop (900 px and wider).
- Keyboard: `←` `→` screens, `⌫` back, `Enter` taps the visible primary
  button, `1`–`9` jump to a flow, `E` validation states, `O` dark theme,
  `C` comment, `M` menu, `D` PDF, `?` help.
- Alternate screens (`data-alterna`) are reached only through the mockup's
  own buttons and do not count as steps.
- The comment box saves by itself to `comentarios/index.md`, one `##`
  section per screen, and shows "guardado ✓".

The UI text is in Spanish (it is for Mexican reviewers). The code is in
English.

## Project layout

```
design/
  mockups/
    mockups.json        the manifest (below)
    auth.html           one file per flow, several <div class="frame"> each
    onboarding.html
    web-dashboard.html  desktop pages, no frames
  comentarios/
    index.md            written by the viewer
```

A flow file holds several screens, each a
`<div class="frame" style="width:390px;height:844px">`. An alternate screen
carries `data-alterna data-padre="N" data-paso="x/y" data-clave="name"`.
Buttons with `data-ir="N"` jump to screen N, `data-ir="+1"` to the next flow,
`data-ir="flow/N"` to screen N of another flow; `data-atras` goes back.

## The manifest: `mockups.json`

Lives in the mockups directory, next to the HTML files. The viewer fetches
it on load and builds the title, the flow list, the "Web" group and the PDF
link from it.

```json
{
  "title": "CazaFacturas · Mockups",
  "flows": [
    { "id": "auth", "title": "Cuenta (entrar)", "src": "redesign-auth.html", "spec": "../specs/auth.md" },
    { "id": "onboarding", "title": "Onboarding", "src": "redesign-onboarding.html" }
  ],
  "web": [
    { "title": "Dashboard (escritorio)", "src": "redesign-web-dashboard.html" }
  ],
  "links": [
    { "title": "Figma", "href": "https://www.figma.com/file/..." }
  ],
  "pdf": "revision.pdf"
}
```

| Key | Required | Meaning |
|---|---|---|
| `title` | yes | Page title, sidebar heading, and the heading of the comments file. |
| `flows[]` | yes, at least one | The app flows, in reading order. |
| `flows[].id` | yes | Letters, digits, `_`, `-`. Used in the URL hash (`#auth/2`) and in `data-ir="auth/2"` jumps. |
| `flows[].title` | yes | Shown in the menu. Comment headings are `<title>` and `<title> · p/n`. |
| `flows[].src` | yes | The HTML file, relative to the mockups directory. |
| `flows[].spec` | no | A relative URL to the written spec (for example `../specs/auth.md`). Shows a small "Spec" link beside the flow, in the sidebar and in the mobile menu. Opens in a new tab. Markdown is served as plain text. |
| `web[]` | no | Desktop pages: `{ "title", "src" }`. Listed under "Web", open in a new tab. |
| `links[]` | no | Plain links: `{ "title", "href" }`. Listed under "Web" after the pages. |
| `pdf` | no | A PDF for download. The link and the `D` shortcut are hidden when absent. |

The viewer needs an HTTP server: it fetches `mockups.json` and the comments,
so opening `index.html` as a file does not work.

## The CLI (any project)

From the workspace:

```
dart run mockup_viewer --dir design/mockups --comments design/comentarios --port 8100 --open
```

Options: `--dir` (default `.`), `--comments` (default: a `comentarios`
directory next to `--dir`), `--port` (default 8100), `--host` (default
127.0.0.1), `--open`.

Routes: `/` and `/index.html` serve the viewer; `GET|PUT /comentarios/<name>`
read and write `<comments>/<name>.md`; everything else is a static file from
the mockups directory.

Install it globally from git:

```
dart pub global activate --source git https://github.com/framallo/mockup_viewer.git --git-path packages/mockup_viewer
mockup_viewer --dir design/mockups --open
```

## The Serverpod adapter

Add the dependency:

```yaml
dependencies:
  mockup_viewer_serverpod:
    git:
      url: https://github.com/framallo/mockup_viewer.git
      path: packages/mockup_viewer_serverpod
```

Mount it, in development only:

```dart
import 'package:mockup_viewer_serverpod/mockup_viewer_serverpod.dart';

if (config.runMode == 'development') {
  mountMockups(pod, dir: 'design/mockups', comments: 'design/comentarios');
}
```

`dir` is tried as given and then as `../dir`, because `serverpod start` runs
from the server package while the design files usually live at the repo root.
`comments` follows the same prefix and defaults to `comentarios` next to
`dir`. When the mockups directory is missing nothing is mounted. `mount`
defaults to `/mockups`.

Routes: `/mockups` and `/mockups/index.html` redirect to `/mockups/`, which
serves the viewer. `GET|PUT /mockups/comentarios/<name>` read and write the
comment file. `/mockups/<file>` serves the directory.

The viewer must stay at `mount/` with the trailing slash, so the flow files
resolve relative to the directory. If the server has a middleware that strips
trailing slashes, exempt `mount/` from it. The adapter does not do that for
you.

## The library

`package:mockup_viewer/mockup_viewer.dart` exports:

- `viewerHtml`: the viewer page as a string.
- `Manifest.parse(json)`: the parsed `mockups.json`, with a
  `ManifestException` on a bad shape.
- `MockupSite(mockups:, comments:)`: `indexHtml`, `resolveFile(path)` (null
  when outside the directory or missing), `contentTypeFor(path)`,
  `readComment(name)`, `writeComment(name, text)`,
  `isValidCommentName(name)` (`^[\w.-]+$`, never `..`).
- `mockupHandler(site)`: the shelf handler the CLI serves.

## Development

The viewer source is `packages/mockup_viewer/viewer/index.html`. It is
embedded into `lib/src/viewer_html.dart` by:

```
cd packages/mockup_viewer && dart run tool/embed.dart
```

Keep both files in sync; a test fails when they differ. Run the tests from
each package directory with `dart test`.

## License

MIT. See `LICENSE`.
