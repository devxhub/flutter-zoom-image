/// flutter_zoom_image — Flutter interactive image zoom package.
///
/// One import, two widgets:
/// ```dart
/// import 'package:flutter_zoom_image/flutter_zoom_image.dart';
///
/// // Full image zoom (scroll, pinch, pan, double-tap)
/// ZoomImage(image: NetworkImage('https://...'))
///
/// // Draggable magnifier tile
/// TileZoom(image: NetworkImage('https://...'))
/// ```
library flutter_zoom_image;

/// Full image zoom widget — scroll, pinch, pan, double-tap, controls.
export 'src/zoom_image.dart' show ZoomImage;

/// Controller — programmatic zoom/pan API.
export 'src/zoom_image_controller.dart' show ZoomImageController;

/// Decoration — background color, border, border-radius, shadow.
export 'src/zoom_image_decoration.dart' show ZoomImageDecoration;

/// Controls style — position, size, colors of the +/−/reset strip.
export 'src/zoom_image_control_style.dart' show ZoomImageControlsStyle;

/// Draggable magnifier tile — zooms a region of the image in-place.
export 'src/deep_zoom/tile_zoom.dart' show TileZoom;