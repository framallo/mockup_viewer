import 'dart:io';

import 'package:args/args.dart';
import 'package:mockup_viewer/mockup_viewer.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

/// Serves a mockups directory with the viewer and the comment box.
///
/// ```
/// dart run mockup_viewer --dir design/mockups --comments design/comentarios
/// ```
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'dir',
      abbr: 'd',
      help: 'Directory with mockups.json and the HTML files.',
      defaultsTo: '.',
    )
    ..addOption(
      'comments',
      abbr: 'c',
      help:
          'Directory for the comment files. Default: ../comentarios next to --dir.',
    )
    ..addOption(
      'port',
      abbr: 'p',
      help: 'Port to listen on.',
      defaultsTo: '8100',
    )
    ..addOption('host', help: 'Address to bind.', defaultsTo: '127.0.0.1')
    ..addFlag(
      'open',
      help: 'Open the viewer in the default browser.',
      negatable: false,
    )
    ..addFlag('help', abbr: 'h', help: 'Show this help.', negatable: false);

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exit(64);
  }
  if (opts['help'] as bool) {
    stdout.writeln('Usage: mockup_viewer [options]\n\n${parser.usage}');
    return;
  }

  final mockups = Directory(p.normalize(p.absolute(opts['dir'] as String)));
  if (!mockups.existsSync()) {
    stderr.writeln('no such directory: ${mockups.path}');
    exit(66);
  }
  final commentsArg = opts['comments'] as String?;
  final comments = Directory(
    commentsArg != null
        ? p.normalize(p.absolute(commentsArg))
        : p.join(p.dirname(mockups.path), 'comentarios'),
  );
  final site = MockupSite(mockups: mockups, comments: comments);

  try {
    final manifest = await site.readManifest();
    stdout.writeln('${manifest.title}: ${manifest.flows.length} flows');
  } on ManifestException catch (e) {
    stderr.writeln('warning: $e');
  }

  final port = int.tryParse(opts['port'] as String);
  if (port == null) {
    stderr.writeln('--port must be a number');
    exit(64);
  }
  final handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(mockupHandler(site));
  final server = await io.serve(handler, opts['host'] as String, port);
  final url = 'http://${server.address.host}:${server.port}/';
  stdout.writeln('mockups: ${mockups.path}');
  stdout.writeln('comments: ${comments.path}');
  stdout.writeln('viewer: $url');

  if (opts['open'] as bool) _open(url);
}

void _open(String url) {
  final cmd = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
      ? 'start'
      : 'xdg-open';
  Process.run(cmd, [url], runInShell: Platform.isWindows).ignore();
}
