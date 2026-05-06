import 'dart:math' as math;
import 'dart:ui';

/// Parsed representation of a Deep Zoom Image (DZI) manifest.
///
/// A `.dzi` file is a small XML document that describes a tiled image:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <Image xmlns="http://schemas.microsoft.com/deepzoom/2008"
///        Format="jpeg" Overlap="1" TileSize="256">
///   <Size Width="32000" Height="18000"/>
/// </Image>
/// ```
///
/// The actual tiles are stored in a sibling directory named `<name>_files/`
/// with sub-directories per zoom level (0, 1, 2 … maxLevel), each containing
/// `col_row.jpg` (or `.png`) files.
class DziDescriptor {
  const DziDescriptor({
    required this.baseUrl,
    required this.width,
    required this.height,
    required this.tileSize,
    required this.overlap,
    required this.format,
  });

  /// The URL of the `.dzi` file (without the filename).
  /// Tiles are fetched from `$baseUrl/<level>/<col>_<row>.<format>`.
  final String baseUrl;

  /// Full image width in pixels.
  final int width;

  /// Full image height in pixels.
  final int height;

  /// Tile size in pixels (tiles are square, default 256).
  final int tileSize;

  /// Number of pixels tiles overlap on each edge (default 1).
  final int overlap;

  /// Image format — `"jpeg"` or `"png"`.
  final String format;

  // ─── Computed properties ────────────────────────────────────────────────────

  /// Maximum zoom level index (level 0 = 1×1 tile, maxLevel = full resolution).
  int get maxLevel => (math.log(math.max(width, height)) / math.log(2)).ceil();

  /// Number of tiles horizontally at [level].
  int colsAtLevel(int level) {
    final scale = math.pow(2, maxLevel - level).toInt();
    return ((width / scale) / tileSize).ceil();
  }

  /// Number of tiles vertically at [level].
  int rowsAtLevel(int level) {
    final scale = math.pow(2, maxLevel - level).toInt();
    return ((height / scale) / tileSize).ceil();
  }

  /// Width of the full image at [level] in pixels.
  int widthAtLevel(int level) {
    final scale = math.pow(2, maxLevel - level).toInt();
    return (width / scale).ceil();
  }

  /// Height of the full image at [level] in pixels.
  int heightAtLevel(int level) {
    final scale = math.pow(2, maxLevel - level).toInt();
    return (height / scale).ceil();
  }

  /// The DZI level index that best matches [viewportZoom] given [widgetSize].
  ///
  /// Returns a level where one image pixel ≈ one screen pixel.
  int bestLevel(double viewportZoom, Size widgetSize) {
    // How many image pixels fit across the widget at this zoom.
    final displayedWidth = widgetSize.width / viewportZoom;
    // We want the tile-level where levelWidth ≈ displayedWidth.
    final ratio = width / displayedWidth;
    final level = (maxLevel - math.log(ratio) / math.log(2)).round();
    return level.clamp(0, maxLevel);
  }

  /// URL for the tile at [level], column [col], row [row].
  String tileUrl(int level, int col, int row) =>
      '$baseUrl/${level}/${col}_$row.$format';

  // ─── Parsing ────────────────────────────────────────────────────────────────

  /// Parse a DZI XML string.
  ///
  /// Throws [FormatException] if the XML is malformed or missing required fields.
  static DziDescriptor parse(String xmlContent, String baseUrl) {
    // Simple regex-based parser — avoids requiring an XML dependency.
    int? _intAttr(String attr) {
      final m = RegExp('$attr="(\\d+)"', caseSensitive: false)
          .firstMatch(xmlContent);
      return m != null ? int.parse(m.group(1)!) : null;
    }

    String? _strAttr(String attr) {
      final m = RegExp('$attr="([^"]+)"', caseSensitive: false)
          .firstMatch(xmlContent);
      return m?.group(1);
    }

    final w = _intAttr('Width');
    final h = _intAttr('Height');
    final ts = _intAttr('TileSize');
    final ov = _intAttr('Overlap') ?? 1;
    final fmt = _strAttr('Format') ?? 'jpeg';

    if (w == null || h == null || ts == null) {
      throw const FormatException(
        'Invalid DZI: missing Width, Height, or TileSize',
      );
    }

    return DziDescriptor(
      baseUrl: baseUrl,
      width: w,
      height: h,
      tileSize: ts,
      overlap: ov,
      format: fmt,
    );
  }

  @override
  String toString() =>
      'DziDescriptor($width×$height ts=$tileSize ol=$overlap fmt=$format levels=$maxLevel)';
}

/// Identifies a single tile within a DZI image pyramid.
class TileId {
  const TileId({required this.level, required this.col, required this.row});

  final int level;
  final int col;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is TileId &&
          other.level == level &&
          other.col == col &&
          other.row == row;

  @override
  int get hashCode => Object.hash(level, col, row);

  @override
  String toString() => 'Tile($level/$col×$row)';
}