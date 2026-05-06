import 'dart:collection';
import 'dart:ui' as ui;

/// LRU (Least-Recently-Used) cache for decoded tile [ui.Image] objects.
///
/// When [capacity] is reached, the tile that was accessed least recently
/// is evicted to free memory.
///
/// Usage:
/// ```dart
/// final cache = TileCache(capacity: 256);
/// cache.put(tileId, image);
/// final img = cache.get(tileId); // null if not cached
/// cache.evict(tileId);
/// cache.clear();
/// ```
class TileCache {
  TileCache({this.capacity = 256});

  /// Maximum number of tiles held in memory simultaneously.
  final int capacity;

  // LinkedHashMap preserves insertion order; we move accessed entries to end.
  final LinkedHashMap<String, ui.Image> _store =
  LinkedHashMap<String, ui.Image>();

  int get size => _store.length;

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Returns the cached [ui.Image] for [key], or null if not present.
  /// Moves the entry to the "most recently used" position.
  ui.Image? get(String key) {
    final img = _store.remove(key);
    if (img == null) return null;
    _store[key] = img; // re-insert at end = most recently used
    return img;
  }

  /// Stores [image] under [key], evicting LRU entries if over capacity.
  void put(String key, ui.Image image) {
    if (_store.containsKey(key)) {
      _store.remove(key);
    } else if (_store.length >= capacity) {
      // Remove least-recently-used (first entry in insertion-order map).
      final lruKey = _store.keys.first;
      _store.remove(lruKey)?.dispose();
    }
    _store[key] = image;
  }

  /// Returns true if [key] is in cache (without updating LRU order).
  bool containsKey(String key) => _store.containsKey(key);

  /// Removes [key] from cache and disposes the image.
  void evict(String key) {
    _store.remove(key)?.dispose();
  }

  /// Disposes all cached images and clears the cache.
  void clear() {
    for (final img in _store.values) {
      img.dispose();
    }
    _store.clear();
  }
}

/// In-flight tile fetch tracker — prevents duplicate network requests.
///
/// A tile URL is added to [pending] when a fetch starts and removed when
/// it completes (success or failure).
class PendingTileSet {
  final Set<String> _pending = {};

  bool isLoading(String key) => _pending.contains(key);
  void markLoading(String key) => _pending.add(key);
  void markDone(String key) => _pending.remove(key);
  void clear() => _pending.clear();
  int get count => _pending.length;
}