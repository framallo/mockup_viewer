import 'package:mockup_viewer/mockup_viewer.dart';
import 'package:test/test.dart';

void main() {
  group('Manifest.parse', () {
    test('parses a full manifest', () {
      final m = Manifest.parse('''
{
  "title": "Demo · Mockups",
  "flows": [
    {"id": "auth", "title": "Cuenta", "src": "auth.html", "spec": "specs/auth.md"},
    {"id": "home", "title": "Inicio", "src": "home.html"}
  ],
  "web": [{"title": "Dashboard", "src": "web.html"}],
  "links": [{"title": "Figma", "href": "https://figma.com/x"}],
  "pdf": "revision.pdf"
}
''');
      expect(m.title, 'Demo · Mockups');
      expect(m.flows.map((f) => f.id), ['auth', 'home']);
      expect(m.flows.first.spec, 'specs/auth.md');
      expect(m.flows.last.spec, isNull);
      expect(m.web.single.href, 'web.html');
      expect(m.links.single.href, 'https://figma.com/x');
      expect(m.pdf, 'revision.pdf');
    });

    test('web, links and pdf are optional', () {
      final m = Manifest.parse(
        '{"title":"T","flows":[{"id":"a","title":"A","src":"a.html"}]}',
      );
      expect(m.web, isEmpty);
      expect(m.links, isEmpty);
      expect(m.pdf, isNull);
    });

    test('rejects invalid JSON with a clear message', () {
      expect(
        () => Manifest.parse('{nope'),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('rejects a missing title', () {
      expect(
        () =>
            Manifest.parse('{"flows":[{"id":"a","title":"A","src":"a.html"}]}'),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('"title"'),
          ),
        ),
      );
    });

    test('rejects empty flows', () {
      expect(
        () => Manifest.parse('{"title":"T","flows":[]}'),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('"flows"'),
          ),
        ),
      );
    });

    test('rejects a flow without src', () {
      expect(
        () => Manifest.parse('{"title":"T","flows":[{"id":"a","title":"A"}]}'),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('flows[0].src'),
          ),
        ),
      );
    });

    test('rejects duplicate and malformed ids', () {
      expect(
        () => Manifest.parse(
          '{"title":"T","flows":[{"id":"a","title":"A","src":"a.html"},{"id":"a","title":"B","src":"b.html"}]}',
        ),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('duplicate'),
          ),
        ),
      );
      expect(
        () => Manifest.parse(
          '{"title":"T","flows":[{"id":"a/b","title":"A","src":"a.html"}]}',
        ),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('flows[0].id'),
          ),
        ),
      );
    });

    test('rejects a link without href', () {
      expect(
        () => Manifest.parse(
          '{"title":"T","flows":[{"id":"a","title":"A","src":"a.html"}],"links":[{"title":"X"}]}',
        ),
        throwsA(
          isA<ManifestException>().having(
            (e) => e.message,
            'message',
            contains('links[0].href'),
          ),
        ),
      );
    });
  });
}
