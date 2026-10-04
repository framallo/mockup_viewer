// The Route classes are not exercised here: Relic's Request constructor is
// private, and a Serverpod web server needs a full config. Their decisions
// live in lib/src/paths.dart and are tested below. The integration check is
// manual: mount it in a server and open mount/ in a browser.
import 'package:mockup_viewer_serverpod/mockup_viewer_serverpod.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeMount', () {
    expect(normalizeMount('/mockups'), '/mockups');
    expect(normalizeMount('/mockups/'), '/mockups');
    expect(normalizeMount('mockups'), '/mockups');
    expect(normalizeMount('/'), '/');
  });

  test('indexRedirect sends mount and index.html to mount/', () {
    expect(indexRedirect('/mockups', '/mockups'), '/mockups/');
    expect(indexRedirect('/mockups', '/mockups/index.html'), '/mockups/');
    expect(indexRedirect('/mockups', '/mockups/'), isNull);
    expect(indexRedirect('/', '/'), isNull);
  });

  test('commentName takes exactly one segment after comentarios', () {
    expect(commentName(['mockups', 'comentarios', 'index']), 'index');
    expect(commentName(['comentarios', 'index']), 'index');
    expect(commentName(['mockups', 'comentarios']), isNull);
    expect(commentName(['mockups', 'comentarios', '']), isNull);
    expect(commentName(['mockups', 'comentarios', 'a', 'b']), isNull);
    expect(commentName(['mockups', 'x']), isNull);
  });
}
