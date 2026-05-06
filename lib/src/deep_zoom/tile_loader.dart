import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'dzi_descriptor.dart';
import 'tile_cache.dart';
import 'package:http/http.dart' as http;
/// Manages fetching and caching of DZI tiles.
///
/// - Fetches and parses the `.dzi` XML manifest on first use.
/// - Fetches individual tile images on demand via [loadTile].
/// - Uses [TileCache] (LRU) to cap memory usage.
/// - Uses [PendingTileSet] to deduplicate in-flight requests.
/// - Prefetches neighbors of visible tiles when [prefetchNeighbors] is true.
class TileLoader extends ChangeNotifier {
  TileLoader({
    required this.dziUrl,
    int cacheCapacity = 256,
    this.prefetchNeighbors = true,
    Map<String, String>? headers,
  })  : _cache = TileCache(capacity: cacheCapacity),
        _pending = PendingTileSet(),
        _headers = headers ?? const {};

  /// Full URL to the `.dzi` manifest file.
  final String dziUrl;

  /// Whether to prefetch adjacent tiles around visible ones.
  final bool prefetchNeighbors;

  final TileCache _cache;
  final PendingTileSet _pending;
  final Map<String, String> _headers;

  DziDescriptor? _descriptor;
  bool _loading = false;
  Object? _error;

  // ─── State getters ──────────────────────────────────────────────────────────

  DziDescriptor? get descriptor => _descriptor;
  bool get isLoading => _loading;
  bool get hasError => _error != null;
  Object? get error => _error;
  bool get isReady => _descriptor != null && !_loading && !hasError;

  int get cachedTileCount => _cache.size;

  // ─── Manifest ───────────────────────────────────────────────────────────────

  /// Fetch and parse the DZI manifest. Call once during widget init.
  Future<void> loadManifest() async {
    if (_descriptor != null || _loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(dziUrl), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} fetching $dziUrl');
      }

      // Base URL = manifest URL minus the `.dzi` filename.
      // e.g. https://example.com/image.dzi → https://example.com/image_files
      final base = dziUrl.replaceAll(RegExp(r'\.dzi$', caseSensitive: false), '_files');
      _descriptor = DziDescriptor.parse(response.body, base);
      _loading = false;
      notifyListeners();
    } catch (e, st) {
      _loading = false;
      _error = e;
      debugPrint('TileLoader: manifest error — $e\n$st');
      notifyListeners();
    }
  }

  // ─── Tile loading ───────────────────────────────────────────────────────────

  /// Returns the cached [ui.Image] for [tile], or null.
  ///
  /// If not cached, starts a background fetch and returns null.
  /// Listeners are notified when the tile arrives so the canvas can repaint.
  ui.Image? getTile(TileId tile) {
    final key = _key(tile);
    final cached = _cache.get(key);
    if (cached != null) return cached;

    if (!_pending.isLoading(key)) {
      _fetchTile(tile);
    }
    return null;
  }

  /// Eagerly pre-load [tiles] without waiting for a repaint request.
  void prefetch(List<TileId> tiles) {
    for (final t in tiles) {
      final key = _key(t);
      if (!_cache.containsKey(key) && !_pending.isLoading(key)) {
        _fetchTile(t);
      }
    }
  }

  Future<void> _fetchTile(TileId tile) async {
    final desc = _descriptor;
    if (desc == null) return;

    final key = _key(tile);
    _pending.markLoading(key);

    try {
      final url = desc.tileUrl(tile.level, tile.col, tile.row);
      final response = await http.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} for tile $tile');
      }

      final image = await _decodeImage(response.bodyBytes);
      _cache.put(key, image);
      notifyListeners(); // triggers repaint
    } catch (e) {
      // Tile fetch failure is non-fatal — just skip that tile.
      debugPrint('TileLoader: tile $tile failed — $e');
    } finally {
      _pending.markDone(key);
    }
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // ─── Visible tile computation ───────────────────────────────────────────────

  /// Computes which tiles are visible given the current viewport.
  ///
  /// [level]      — the DZI pyramid level to render
  /// [offset]     — pan offset from [ZoomImageController]
  /// [zoom]       — current zoom from [ZoomImageController]
  /// [widgetSize] — the widget's pixel dimensions
  List<TileId> visibleTiles({
    required int level,
    required Offset offset,
    required double zoom,
    required Size widgetSize,
  }) {
    final desc = _descriptor;
    if (desc == null) return const [];

    final cols = desc.colsAtLevel(level);
    final rows = desc.rowsAtLevel(level);

    // Scale factor from level-pixels to screen-pixels.
    // At maxLevel the image occupies (desc.width * zoom) screen pixels.
    final levelScale = zoom / math.pow(2, desc.maxLevel - level);
    final tileScreenSize = desc.tileSize * levelScale;

    // Which tiles are on screen?
    final x0 = (-offset.dx / tileScreenSize).floor().clamp(0, cols - 1);
    final y0 = (-offset.dy / tileScreenSize).floor().clamp(0, rows - 1);
    final x1 = ((widgetSize.width - offset.dx) / tileScreenSize)
        .ceil()
        .clamp(0, cols - 1);
    final y1 = ((widgetSize.height - offset.dy) / tileScreenSize)
        .ceil()
        .clamp(0, rows - 1);

    final tiles = <TileId>[];
    for (var row = y0; row <= y1; row++) {
      for (var col = x0; col <= x1; col++) {
        tiles.add(TileId(level: level, col: col, row: row));
      }
    }
    return tiles;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _key(TileId t) => '${t.level}/${t.col}_${t.row}';

  @override
  void dispose() {
    _cache.clear();
    _pending.clear();
    super.dispose();
  }
}