/// Pure path logic for the Serverpod routes, kept apart so it can be tested
/// without building Relic requests (their constructor is private).
library;

/// Strips a trailing slash from [mount]. `/` stays `/`.
String normalizeMount(String mount) {
  var m = mount.trim();
  if (!m.startsWith('/')) m = '/$m';
  while (m.length > 1 && m.endsWith('/')) {
    m = m.substring(0, m.length - 1);
  }
  return m;
}

/// Where the index route sends a request, or null to serve the viewer.
///
/// The viewer must live at `mount/` WITH the slash, so the flow files resolve
/// relative to the directory. `mount` and `mount/index.html` redirect there.
String? indexRedirect(String mount, String requestPath) {
  final canonical = mount == '/' ? '/' : '$mount/';
  if (requestPath == canonical) return null;
  return canonical;
}

/// The comment name from a request path under `mount/comentarios/`, or null
/// when the path has no single segment after `comentarios`.
String? commentName(List<String> pathSegments) {
  final i = pathSegments.indexOf('comentarios');
  if (i < 0) return null;
  final rest = pathSegments.skip(i + 1).where((s) => s.isNotEmpty).toList();
  if (rest.length != 1) return null;
  return rest.single;
}
