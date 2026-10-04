/// A phone viewer for disposable HTML mockups with a per-screen comment box.
///
/// The project keeps only its HTML files plus `mockups.json`. This library
/// holds the viewer page ([viewerHtml]), the manifest parser ([Manifest]),
/// the file and comment logic ([MockupSite]) and a shelf handler
/// ([mockupHandler]) used by the CLI.
library;

export 'src/manifest.dart';
export 'src/mockup_site.dart';
export 'src/shelf_handler.dart';
export 'src/viewer_html.dart';
