import 'dart:convert';

/// One flow of the app: a page with several phone screens.
class Flow {
  Flow({required this.id, required this.title, required this.src, this.spec});

  /// Used in the URL hash (`#auth/2`) and in `data-ir="auth/2"` jumps.
  final String id;

  /// Shown in the menu and used as the comment heading.
  final String title;

  /// The HTML file, relative to the mockups directory.
  final String src;

  /// Optional relative URL to the written spec of this flow.
  final String? spec;
}

/// A link shown in the "Web" group. Opens in a new tab.
class Link {
  Link({required this.title, required this.href});

  final String title;
  final String href;
}

/// The parsed `mockups.json`.
///
/// ```json
/// {
///   "title": "My app · Mockups",
///   "flows": [{"id": "auth", "title": "Sign in", "src": "auth.html", "spec": "../specs/auth.md"}],
///   "web": [{"title": "Dashboard", "src": "web-dashboard.html"}],
///   "links": [{"title": "Figma", "href": "https://..."}],
///   "pdf": "review.pdf"
/// }
/// ```
///
/// `web`, `links`, `pdf` and every `spec` are optional.
class Manifest {
  Manifest({
    required this.title,
    required this.flows,
    this.web = const [],
    this.links = const [],
    this.pdf,
  });

  /// Parses the JSON text. Throws [ManifestException] with a plain message
  /// when the shape is wrong.
  factory Manifest.parse(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw ManifestException('mockups.json is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw ManifestException('mockups.json must be a JSON object');
    }
    return Manifest.fromMap(decoded);
  }

  /// Builds a manifest from an already decoded JSON object.
  factory Manifest.fromMap(Map<String, Object?> map) {
    final title = map['title'];
    if (title is! String || title.trim().isEmpty) {
      throw ManifestException('"title" must be a non-empty string');
    }
    final flowsRaw = map['flows'];
    if (flowsRaw is! List || flowsRaw.isEmpty) {
      throw ManifestException('"flows" must be a non-empty list');
    }
    final flows = <Flow>[];
    final ids = <String>{};
    for (var i = 0; i < flowsRaw.length; i++) {
      final f = flowsRaw[i];
      if (f is! Map) throw ManifestException('flows[$i] must be an object');
      final id = _string(f, 'id', 'flows[$i]');
      if (!RegExp(r'^[\w-]+$').hasMatch(id)) {
        throw ManifestException(
          'flows[$i].id "$id" may only contain letters, digits, _ and -',
        );
      }
      if (!ids.add(id)) throw ManifestException('duplicate flow id "$id"');
      final spec = f['spec'];
      if (spec != null && (spec is! String || spec.isEmpty)) {
        throw ManifestException('flows[$i].spec must be a non-empty string');
      }
      flows.add(
        Flow(
          id: id,
          title: _string(f, 'title', 'flows[$i]'),
          src: _string(f, 'src', 'flows[$i]'),
          spec: spec as String?,
        ),
      );
    }
    final web = _links(map['web'], 'web', 'src');
    final links = _links(map['links'], 'links', 'href');
    final pdf = map['pdf'];
    if (pdf != null && (pdf is! String || pdf.isEmpty)) {
      throw ManifestException('"pdf" must be a non-empty string');
    }
    return Manifest(
      title: title.trim(),
      flows: flows,
      web: web,
      links: links,
      pdf: pdf as String?,
    );
  }

  final String title;
  final List<Flow> flows;

  /// Desktop pages: standalone HTML files without phone frames.
  final List<Link> web;

  /// Plain links, shown after [web].
  final List<Link> links;

  /// Optional PDF for download.
  final String? pdf;

  static String _string(Map<Object?, Object?> m, String key, String where) {
    final v = m[key];
    if (v is! String || v.isEmpty) {
      throw ManifestException('$where.$key must be a non-empty string');
    }
    return v;
  }

  static List<Link> _links(Object? raw, String key, String hrefKey) {
    if (raw == null) return const [];
    if (raw is! List) throw ManifestException('"$key" must be a list');
    final out = <Link>[];
    for (var i = 0; i < raw.length; i++) {
      final l = raw[i];
      if (l is! Map) throw ManifestException('$key[$i] must be an object');
      out.add(
        Link(
          title: _string(l, 'title', '$key[$i]'),
          href: _string(l, hrefKey, '$key[$i]'),
        ),
      );
    }
    return out;
  }
}

/// A readable error about `mockups.json`.
class ManifestException implements Exception {
  ManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}
