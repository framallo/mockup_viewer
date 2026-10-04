import 'dart:io';

import 'package:mockup_viewer/mockup_viewer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late MockupSite site;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mockup_viewer_');
    final mockups = Directory(p.join(tmp.path, 'mockups'))..createSync();
    File(
      p.join(mockups.path, 'auth.html'),
    ).writeAsStringSync('<div class="frame"></div>');
    Directory(p.join(mockups.path, 'sub')).createSync();
    File(p.join(mockups.path, 'sub', 'x.css')).writeAsStringSync('body{}');
    File(p.join(tmp.path, 'secret.txt')).writeAsStringSync('nope');
    site = MockupSite(
      mockups: mockups,
      comments: Directory(p.join(tmp.path, 'comentarios')),
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  group('isValidCommentName', () {
    test('accepts simple names', () {
      expect(MockupSite.isValidCommentName('index'), isTrue);
      expect(MockupSite.isValidCommentName('ronda-2.v1_final'), isTrue);
    });

    test('rejects traversal, slashes, absolute paths, spaces and empty', () {
      expect(MockupSite.isValidCommentName(''), isFalse);
      expect(MockupSite.isValidCommentName('..'), isFalse);
      expect(MockupSite.isValidCommentName('../x'), isFalse);
      expect(MockupSite.isValidCommentName('a..b'), isFalse);
      expect(MockupSite.isValidCommentName('mockups/index'), isFalse);
      expect(MockupSite.isValidCommentName('/etc/passwd'), isFalse);
      expect(MockupSite.isValidCommentName('con espacio'), isFalse);
      expect(MockupSite.isValidCommentName('a\\b'), isFalse);
    });
  });

  group('resolveFile', () {
    test('finds files inside the mockups dir', () {
      expect(site.resolveFile('auth.html'), isNotNull);
      expect(site.resolveFile('/auth.html'), isNotNull);
      expect(site.resolveFile('sub/x.css'), isNotNull);
    });

    test('returns null for missing files', () {
      expect(site.resolveFile('nope.html'), isNull);
      expect(site.resolveFile(''), isNull);
    });

    test('returns null outside the dir', () {
      expect(site.resolveFile('../secret.txt'), isNull);
      expect(site.resolveFile('sub/../../secret.txt'), isNull);
      expect(site.resolveFile(p.join(tmp.path, 'secret.txt')), isNull);
    });
  });

  test('contentTypeFor', () {
    expect(site.contentTypeFor('a.html'), 'text/html; charset=utf-8');
    expect(site.contentTypeFor('m.json'), 'application/json; charset=utf-8');
    expect(site.contentTypeFor('s.md'), 'text/plain; charset=utf-8');
    expect(site.contentTypeFor('r.pdf'), 'application/pdf');
    expect(site.contentTypeFor('x.bin'), 'application/octet-stream');
  });

  group('comments', () {
    test('missing file reads as empty', () async {
      expect(await site.readComment('index'), '');
    });

    test('write then read round trip, creating the directory', () async {
      await site.writeComment('index', '# Comentarios\n\n## Cuenta\n\nhola\n');
      expect(
        File(p.join(tmp.path, 'comentarios', 'index.md')).existsSync(),
        isTrue,
      );
      expect(
        await site.readComment('index'),
        '# Comentarios\n\n## Cuenta\n\nhola\n',
      );
    });

    test('invalid names throw', () {
      expect(() => site.readComment('../x'), throwsArgumentError);
      expect(() => site.writeComment('a b', 'x'), throwsArgumentError);
    });
  });

  test('indexHtml is the viewer and matches viewer/index.html', () {
    expect(site.indexHtml, contains('mockups.json'));
    expect(
      site.indexHtml,
      contains("new URL(\"comentarios/index\", location.href)"),
    );
    final onDisk = File('viewer/index.html').readAsStringSync();
    expect(viewerHtml, onDisk, reason: 'run `dart run tool/embed.dart`');
  });
}
