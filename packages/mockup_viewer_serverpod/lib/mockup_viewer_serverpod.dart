/// Mounts the mockup viewer on a Serverpod web server.
///
/// ```dart
/// if (config.runMode == 'development') {
///   mountMockups(pod, dir: 'design/mockups', comments: 'design/comentarios');
/// }
/// ```
///
/// Routes, with the default `mount: '/mockups'`:
///
/// - `GET /mockups` and `/mockups/index.html` redirect to `/mockups/`.
/// - `GET /mockups/` serves the embedded viewer.
/// - `GET|PUT /mockups/comentarios/<name>` read and write `<comments>/<name>.md`.
/// - `GET /mockups/<file>` serves the mockups directory.
///
/// The caller must exempt `mount/` from any trailing-slash redirect
/// middleware, and should call this only in development.
library;

import 'dart:io';

import 'package:mockup_viewer/mockup_viewer.dart';
import 'package:serverpod/serverpod.dart';

import 'src/paths.dart';

export 'src/paths.dart' show commentName, indexRedirect, normalizeMount;

/// Registers the viewer, the comment routes and the static files at [mount].
///
/// [dir] is resolved against the working directory: first `dir`, then
/// `../dir` (`serverpod start` runs from the server package while the design
/// files usually live at the repo root). [comments] follows the same prefix;
/// when empty it defaults to a `comentarios` directory next to [dir].
/// Does nothing when the mockups directory is missing.
void mountMockups(
  Serverpod pod, {
  required String dir,
  String comments = '',
  String mount = '/mockups',
}) {
  final prefix = ['', '../'].cast<String?>().firstWhere(
    (p) => Directory('$p$dir').existsSync(),
    orElse: () => null,
  );
  if (prefix == null) return;
  final mockups = Directory('$prefix$dir');
  final commentsDir = Directory(
    comments.isEmpty
        ? '${mockups.parent.path}/comentarios'
        : '$prefix$comments',
  );
  final site = MockupSite(mockups: mockups, comments: commentsDir);
  final m = normalizeMount(mount);

  final index = MockupIndexRoute(site, mount: m);
  pod.webServer.addRoute(index, m);
  pod.webServer.addRoute(index, '$m/index.html');
  // Before the static route, so it wins over `mount/**`.
  pod.webServer.addRoute(MockupCommentsRoute(site), '$m/comentarios/**');
  pod.webServer.addRoute(StaticRoute.directory(mockups), m);
}

/// The viewer. Lives at `mount/` WITH the trailing slash; anything else
/// redirects there.
class MockupIndexRoute extends Route {
  MockupIndexRoute(this.site, {required this.mount})
    : super(methods: {Method.get, Method.head});

  final MockupSite site;
  final String mount;

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final to = indexRedirect(mount, request.url.path);
    if (to != null) {
      return Response.movedPermanently(request.url.replace(path: to));
    }
    return Response.ok(
      body: Body.fromString(site.indexHtml, mimeType: MimeType.html),
      headers: Headers.build(
        (h) => h.cacheControl = CacheControlHeader(noStore: true),
      ),
    );
  }
}

/// `GET|PUT mount/comentarios/<name>`: one Markdown file per name.
class MockupCommentsRoute extends Route {
  MockupCommentsRoute(this.site) : super(methods: {Method.get, Method.put});

  final MockupSite site;

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final name = commentName(request.url.pathSegments);
    if (name == null || !MockupSite.isValidCommentName(name)) {
      return Response.badRequest(
        body: Body.fromString(
          'invalid comment name',
          mimeType: MimeType.plainText,
        ),
      );
    }
    final noStore = Headers.build(
      (h) => h.cacheControl = CacheControlHeader(noStore: true),
    );
    if (request.method == Method.put) {
      await site.writeComment(name, await request.readAsString());
      return Response.ok(
        body: Body.fromString('ok', mimeType: MimeType.plainText),
        headers: noStore,
      );
    }
    return Response.ok(
      body: Body.fromString(
        await site.readComment(name),
        mimeType: MimeType.plainText,
      ),
      headers: noStore,
    );
  }
}
