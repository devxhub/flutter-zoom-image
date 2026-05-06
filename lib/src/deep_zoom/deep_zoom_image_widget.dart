import 'package:flutter/material.dart';

import '../../zoom_image.dart';
import '../zoom_controller.dart';
import '../zoom_image_controller.dart';
import '../zoom_gesture_handler.dart';
import 'dzi_descriptor.dart';
import 'tile_loader.dart';
import 'tile_grid_painter.dart';

/// A widget that displays a Deep Zoom Image (DZI) — a tiled, multi-resolution
/// image pyramid — with full interactive zoom and pan.
///
/// ## How it works
/// 1. Fetches the `.dzi` XML manifest from [dziUrl].
/// 2. Parses the manifest to learn the image dimensions and tile layout.
/// 3. On every repaint, determines which pyramid level best matches the current
///    viewport zoom.
/// 4. Fetches only the tiles visible in the viewport (lazy loading).
/// 5. Falls back to coarser tiles while fine tiles load (progressive reveal).
/// 6. Prefetches neighboring tiles for smooth panning.
/// 7. Caches up to [cacheCapacity] decoded tiles in an LRU cache.
///
/// ## Usage
/// ```dart
/// DeepZoomImageWidget(
///   dziUrl: 'https://example.com/gigapixel.dzi',
/// )
/// ```
///
/// ## With external controller
/// ```dart
/// final ctrl = ZoomImageController(minZoom: 1, maxZoom: 16);
///
/// DeepZoomImageWidget(
///   dziUrl: 'https://example.com/map.dzi',
///   controller: ctrl,
/// )
/// ```
class DeepZoomImageWidget extends StatefulWidget {
  const DeepZoomImageWidget({
    super.key,
    required this.dziUrl,
    this.controller,
    this.minZoom = 1.0,
    this.maxZoom = 16.0,
    this.initialZoom = 1.0,
    this.doubleTapZoom = 3.0,
    this.scrollSensitivity = 0.001,
    this.cacheCapacity = 256,
    this.prefetchNeighbors = true,
    this.showControls = true,
    this.showDebugOverlay = false,
    this.controlsAlignment = Alignment.bottomRight,
    this.controlsPadding = const EdgeInsets.all(12),
    this.backgroundColor = Colors.black,
    this.headers,
    this.onZoomChanged,
    this.onPanChanged,
    this.onManifestLoaded,
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// URL of the `.dzi` manifest file.
  final String dziUrl;

  /// Optional external [ZoomImageController].
  final ZoomImageController? controller;

  /// Minimum zoom (default 1 = fit-to-widget).
  final double minZoom;

  /// Maximum zoom (default 16 — enough for gigapixel images).
  final double maxZoom;

  /// Starting zoom.
  final double initialZoom;

  /// Zoom level on double-tap.
  final double doubleTapZoom;

  /// Mouse wheel zoom sensitivity.
  final double scrollSensitivity;

  /// Maximum number of tiles in the LRU cache (default 256).
  final int cacheCapacity;

  /// Whether to prefetch adjacent tiles during panning.
  final bool prefetchNeighbors;

  /// Show the +/−/reset control strip.
  final bool showControls;

  /// Show a debug overlay with tile stats (level, cache size, in-flight).
  final bool showDebugOverlay;

  /// Position of the controls strip.
  final AlignmentGeometry controlsAlignment;

  final EdgeInsetsGeometry controlsPadding;

  /// Background color shown outside the image.
  final Color backgroundColor;

  /// Optional HTTP headers (e.g. for auth-protected tile servers).
  final Map<String, String>? headers;

  /// Called when the DZI manifest is successfully parsed.
  final ValueChanged<DziDescriptor>? onManifestLoaded;

  final ValueChanged<double>? onZoomChanged;
  final ValueChanged<Offset>? onPanChanged;

  /// Override the loading spinner shown while the manifest loads.
  final WidgetBuilder? loadingBuilder;

  /// Override the error widget shown when manifest fetch fails.
  final Widget Function(BuildContext, Object error)? errorBuilder;

  @override
  State<DeepZoomImageWidget> createState() => _DeepZoomImageWidgetState();
}

class _DeepZoomImageWidgetState extends State<DeepZoomImageWidget> {
  late TileLoader _loader;
  late ZoomImageController _ctrl;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _initController();
    _initLoader();
  }

  void _initController() {
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = ZoomImageController(
        minZoom: widget.minZoom,
        maxZoom: widget.maxZoom,
        initialZoom: widget.initialZoom,
      );
      _ownsController = true;
    }
  }

  void _initLoader() {
    _loader = TileLoader(
      dziUrl: widget.dziUrl,
      cacheCapacity: widget.cacheCapacity,
      prefetchNeighbors: widget.prefetchNeighbors,
      headers: widget.headers,
    );
    _loader.loadManifest().then((_) {
      if (_loader.descriptor != null) {
        widget.onManifestLoaded?.call(_loader.descriptor!);
      }
    });
  }

  @override
  void didUpdateWidget(DeepZoomImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dziUrl != widget.dziUrl) {
      _loader.dispose();
      _initLoader();
    }
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _ctrl.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return ClipRect(
          child: ColoredBox(
            color: widget.backgroundColor,
            child: ListenableBuilder(
              listenable: _loader,
              builder: (_, __) {
                // ── Loading ────────────────────────────────────────────────
                if (_loader.isLoading) {
                  return widget.loadingBuilder?.call(context) ??
                      const _ManifestLoadingWidget();
                }

                // ── Error ─────────────────────────────────────────────────
                if (_loader.hasError) {
                  return widget.errorBuilder?.call(context, _loader.error!) ??
                      _ManifestErrorWidget(error: _loader.error!);
                }

                // ── Ready ─────────────────────────────────────────────────
                final desc = _loader.descriptor!;

                return ZoomGestureHandler(
                  controller: _ctrl,
                  doubleTapZoom: widget.doubleTapZoom,
                  scrollSensitivity: widget.scrollSensitivity,
                  onZoomChanged: widget.onZoomChanged,
                  onPanChanged: widget.onPanChanged,
                  child: Stack(
                    children: [
                      // Tile canvas
                      RepaintBoundary(
                        child: CustomPaint(
                          size: size,
                          painter: TileGridPainter(
                            descriptor: desc,
                            loader: _loader,
                            controller: _ctrl,
                          ),
                        ),
                      ),

                      // Controls
                      if (widget.showControls)
                        ZoomControls(
                          controller: _ctrl,
                          widgetSize: size,
                          alignment: widget.controlsAlignment as Alignment,
                          padding: widget.controlsPadding,
                        ),

                      // Zoom % badge
                      _ZoomBadge(controller: _ctrl),

                      // Debug overlay
                      if (widget.showDebugOverlay)
                        _DebugOverlay(
                          controller: _ctrl,
                          loader: _loader,
                          descriptor: desc,
                          widgetSize: size,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Zoom % badge ──────────────────────────────────────────────────────────────

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.controller});
  final ZoomImageController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, __) => AnimatedOpacity(
          opacity: controller.zoom > controller.minZoom + 0.05 ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: _Badge('${(controller.zoom * 100).round()}%'),
        ),
      ),
    );
  }
}

// ─── Debug overlay ─────────────────────────────────────────────────────────────

class _DebugOverlay extends StatelessWidget {
  const _DebugOverlay({
    required this.controller,
    required this.loader,
    required this.descriptor,
    required this.widgetSize,
  });

  final ZoomImageController controller;
  final TileLoader loader;
  final DziDescriptor descriptor;
  final Size widgetSize;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 60,
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, loader]),
        builder: (_, __) {
          final level = descriptor.bestLevel(controller.zoom, widgetSize);
          final lines = [
            'DZI ${descriptor.width}×${descriptor.height}',
            'Level $level / ${descriptor.maxLevel}',
            'Tiles: ${descriptor.colsAtLevel(level)}×${descriptor.rowsAtLevel(level)}',
            'Cache: ${loader.cachedTileCount}/${loader.prefetchNeighbors ? '∞' : '-'}',
            'Zoom: ${controller.zoom.toStringAsFixed(2)}×',
          ];
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lines
                  .map((l) => Text(l,
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace')))
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

// ─── Loading / error states ────────────────────────────────────────────────────

class _ManifestLoadingWidget extends StatelessWidget {
  const _ManifestLoadingWidget();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        SizedBox(height: 12),
        Text('Loading image manifest…',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    ),
  );
}

class _ManifestErrorWidget extends StatelessWidget {
  const _ManifestErrorWidget({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Failed to load DZI manifest',
              style: TextStyle(color: Colors.white70,
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(error.toString(),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3)),
  );
}