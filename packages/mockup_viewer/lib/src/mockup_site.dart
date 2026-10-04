import 'dart:io';

import 'package:path/path.dart' as p;

import 'manifest.dart';
import 'viewer_html.dart';

/// The mockups of one project: a directory of HTML files plus `mockups.json`,
/// and a directory of comment files.
///
/// Framework-agnostic. The CLI (shelf) and the Serverpod adapter both route
/// requests through this class.
class MockupSite {
  MockupSite({required this.mockups, required this.comments});

  /// The directory with `mockups.json` and the flow HTML files.
  final Directory mockups;

  /// The directory with the comment files (`<name>.md`). Created on first
  /// write.
  final Directory comments;

  /// The viewer page. It loads `mockups.json` from its own directory.
  String get indexHtml => viewerHtml;

  /// The manifest file.
  File get manifestFile => File(p.join(mockups.path, 'mockups.json'));

  /// Reads and parses `mockups.json`. Throws [ManifestException] when the
  /// file is missing or malformed.
  Future<Manifest> readManifest() async {
    if (!manifestFile.existsSync()) {
      throw ManifestException('no mockups.json in ${mockups.path}');
    }
    return Manifest.parse(await manifestFile.readAsString());
  }

  /// Resolves a request path inside [mockups]. Returns null when the path
  /// escapes the directory or the file does not exist.
  File? resolveFile(String relativePath) {
    var rel = relativePath;
    while (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    if (rel.isEmpty || p.isAbsolute(rel) || rel.contains('\\')) return null;
    final root = p.normalize(p.absolute(mockups.path));
    final full = p.normalize(p.join(root, rel));
    if (!p.isWithin(root, full)) return null;
    final file = File(full);
    if (!file.existsSync()) return null;
    return file;
  }

  /// A MIME type from the file extension. Text types get `charset=utf-8`.
  String contentTypeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.html':
      case '.htm':
        return 'text/html; charset=utf-8';
      case '.css':
        return 'text/css; charset=utf-8';
      case '.js':
      case '.mjs':
        return 'text/javascript; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.md':
      case '.txt':
        return 'text/plain; charset=utf-8';
      case '.svg':
        return 'image/svg+xml';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.ico':
        return 'image/x-icon';
      case '.pdf':
        return 'application/pdf';
      case '.woff':
        return 'font/woff';
      case '.woff2':
        return 'font/woff2';
      default:
        return 'application/octet-stream';
    }
  }

  /// A comment name is one path segment: letters, digits, `_`, `.`, `-`.
  /// Never `..`. The viewer uses `index`.
  static bool isValidCommentName(String name) {
    if (name.isEmpty || name.contains('..')) return false;
    return RegExp(r'^[\w.-]+$').hasMatch(name);
  }

  File _commentFile(String name) {
    if (!isValidCommentName(name)) {
      throw ArgumentError.value(name, 'name', 'invalid comment name');
    }
    return File(p.join(comments.path, '$name.md'));
  }

  /// The text of `<comments>/<name>.md`, or an empty string when missing.
  Future<String> readComment(String name) async {
    final file = _commentFile(name);
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  /// Writes `<comments>/<name>.md`, creating the directory when needed.
  Future<void> writeComment(String name, String text) async {
    final file = _commentFile(name);
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }
}
