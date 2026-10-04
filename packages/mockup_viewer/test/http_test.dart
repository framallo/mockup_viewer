import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mockup_viewer/mockup_viewer.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late HttpServer server;
  late Uri base;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mockup_viewer_http_');
    final mockups = Directory(p.join(tmp.path, 'mockups'))..createSync();
    File(p.join(mockups.path, 'mockups.json')).writeAsStringSync(
      '{"title":"Demo","flows":[{"id":"auth","title":"Cuenta","src":"auth.html"}]}',
    );
    File(
      p.join(mockups.path, 'auth.html'),
    ).writeAsStringSync('<div class="frame">hola</div>');
    final site = MockupSite(
      mockups: mockups,
      comments: Directory(p.join(tmp.path, 'comentarios')),
    );
    server = await io.serve(
      mockupHandler(site),
      InternetAddress.loopbackIPv4,
      0,
    );
    base = Uri.parse('http://127.0.0.1:${server.port}/');
  });

  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  test('/ and /index.html serve the embedded viewer', () async {
    for (final path in ['', 'index.html']) {
      final r = await http.get(base.resolve(path));
      expect(r.statusCode, 200);
      expect(r.headers['content-type'], contains('text/html'));
      expect(r.body, viewerHtml);
    }
  });

  test('static files come from the mockups dir', () async {
    final r = await http.get(base.resolve('auth.html'));
    expect(r.statusCode, 200);
    expect(r.body, contains('hola'));
    final m = await http.get(base.resolve('mockups.json'));
    expect(m.statusCode, 200);
    expect(m.headers['content-type'], contains('json'));
  });

  test('missing file is 404', () async {
    expect((await http.get(base.resolve('nope.html'))).statusCode, 404);
  });

  test('comments GET then PUT round trip', () async {
    final url = base.resolve('comentarios/index');
    final empty = await http.get(url);
    expect(empty.statusCode, 200);
    expect(empty.body, '');
    expect(empty.headers['cache-control'], 'no-store');

    const text =
        '# Comentarios · Demo\n\n## Cuenta · 1/2\n\nmás grande el botón\n';
    final put = await http.put(
      url,
      body: text,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );
    expect(put.statusCode, 200);

    final back = await http.get(url);
    expect(back.body, text);
    expect(
      File(p.join(tmp.path, 'comentarios', 'index.md')).readAsStringSync(),
      text,
    );
  });

  test('invalid comment names are 400', () async {
    expect((await http.get(base.resolve('comentarios/'))).statusCode, 400);
    expect((await http.get(base.resolve('comentarios/a%20b'))).statusCode, 400);
    expect(
      (await http.put(base.resolve('comentarios/x/y'), body: 'x')).statusCode,
      400,
    );
    expect(
      (await http.put(
        base.resolve('comentarios/..%2Fx'),
        body: 'x',
      )).statusCode,
      400,
    );
  });

  test('comments reject other methods', () async {
    expect(
      (await http.post(
        base.resolve('comentarios/index'),
        body: 'x',
      )).statusCode,
      405,
    );
  });
}
