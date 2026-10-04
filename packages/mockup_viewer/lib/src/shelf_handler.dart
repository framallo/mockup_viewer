import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

import 'mockup_site.dart';

/// A shelf [Handler] that serves a [MockupSite]:
///
/// - `GET /` and `GET /index.html`: the embedded viewer.
/// - `GET|PUT /comentarios/<name>`: the comment file `<name>.md`.
/// - Everything else: static files from the mockups directory.
Handler mockupHandler(MockupSite site) {
  final static = createStaticHandler(
    site.mockups.path,
    serveFilesOutsidePath: false,
  );
  const noStore = {'cache-control': 'no-store'};

  return (Request request) async {
    final segments = request.url.pathSegments;
    final path = request.url.path;

    if (path.isEmpty || path == 'index.html') {
      if (request.method != 'GET' && request.method != 'HEAD') {
        return Response(405, body: 'method not allowed');
      }
      return Response.ok(
        site.indexHtml,
        headers: {'content-type': 'text/html; charset=utf-8', ...noStore},
      );
    }

    if (segments.isNotEmpty && segments.first == 'comentarios') {
      final name = segments.length == 2 ? segments[1] : '';
      if (!MockupSite.isValidCommentName(name)) {
        return Response.badRequest(body: 'invalid comment name');
      }
      switch (request.method) {
        case 'GET':
          return Response.ok(
            await site.readComment(name),
            headers: {'content-type': 'text/plain; charset=utf-8', ...noStore},
          );
        case 'PUT':
          await site.writeComment(name, await request.readAsString());
          return Response.ok('ok', headers: noStore);
        default:
          return Response(405, body: 'method not allowed');
      }
    }

    return static(request);
  };
}
