import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A widget that displays an image with a draggable magnifier tile.
///
/// The image renders normally at full widget size.
/// A [tileSize] × [tileSize] tile floats on top — draggable anywhere
/// over the image. Inside the tile, the same image is rendered at
/// [zoomLevel] magnification, clipped to show only the region
/// directly beneath the tile. No second panel. No separate view.
///
/// ```dart
/// TileZoom(
///   image: const NetworkImage('https://example.com/photo.jpg'),
///   zoomLevel: 4.0,
///   tileSize: 120,
/// )
/// ```
///
/// ## How it works
///
/// ```
/// Stack
///  ├── Image (full size, BoxFit.contain)          ← base layer
///  └── Positioned tile (draggable)
///       └── ClipRect (60×60 window)
///            └── Transform.translate + scale      ← same image, zoomed
///                 └── Image (full size again)
/// ```
///
/// The translate is computed so that the zoomed image is panned to
/// show exactly the region that sits under the tile on the base layer.
class TileZoom extends StatefulWidget {
  const TileZoom({
    super.key,
    required this.image,

    // Tile appearance
    this.tileSize = 120.0,
    this.zoomLevel = 4.0,
    this.tileBorderColor,
    this.tileBorderWidth = 2.0,
    this.tileBorderRadius = 6.0,
    this.tileElevation = 6.0,

    // Initial position — defaults to widget center
    this.initialOffset,

    // Constraints
    this.clampTileToImage = true,

    // Image fit
    this.fit = BoxFit.contain,
    this.backgroundColor = Colors.black,

    // Callbacks
    this.onTilePositionChanged,
    this.onZoomLevelChanged,

    // Loading / error
    this.placeholder,
    this.errorWidget,
  }) : assert(zoomLevel >= 1.0, 'zoomLevel must be >= 1.0'),
        assert(tileSize > 0, 'tileSize must be positive');

  /// The image source. Any [ImageProvider] works: Network, Asset, Memory…
  final ImageProvider image;

  /// Side length of the square magnifier tile in logical pixels.
  final double tileSize;

  /// How much the image is magnified inside the tile.
  /// 1.0 = no magnification. 4.0 = 4× zoom (default).
  final double zoomLevel;

  /// Color of the tile border ring. Defaults to amber.
  final Color? tileBorderColor;

  /// Width of the tile border ring.
  final double tileBorderWidth;

  /// Corner radius of the tile.
  final double tileBorderRadius;

  /// Shadow elevation of the tile.
  final double tileElevation;

  /// Where the tile starts. If null, it starts at the widget center.
  final Offset? initialOffset;

  /// When true, the tile cannot be dragged outside the image bounds.
  final bool clampTileToImage;

  /// How the base image fits inside the widget bounds.
  final BoxFit fit;

  /// Background color shown outside the image.
  final Color backgroundColor;

  /// Called every time the tile is moved, with the new top-left [Offset].
  final ValueChanged<Offset>? onTilePositionChanged;

  /// Called if you expose a zoom-level control externally (reserved for v2).
  final ValueChanged<double>? onZoomLevelChanged;

  /// Widget shown while the image loads.
  final Widget? placeholder;

  /// Widget shown if the image fails to load.
  final Widget? errorWidget;

  @override
  State<TileZoom> createState() => _TileZoomState();
}

class _TileZoomState extends State<TileZoom> {
  // The single source of truth for tile position.
  // Never reset except when the image itself changes.
  Offset _tileOffset = Offset.zero;

  // False only before the very first layout — used to place the
  // tile at center once. After that, _tileOffset is NEVER touched
  // by didUpdateWidget or build, only by gestures.
  bool _initialPlacementDone = false;

  // Cached widget size so didUpdateWidget can re-clamp without
  // waiting for the next build.
  Size _widgetSize = Size.zero;

  // Drag tracking.
  Offset _dragStartLocal = Offset.zero;
  Offset _dragStartTile = Offset.zero;

  @override
  void didUpdateWidget(TileZoom old) {
    super.didUpdateWidget(old);

    // ── Image swapped ──────────────────────────────────────────
    // Only case where position resets: the image itself changed.
    // This is an explicit, intentional reset — not a side-effect
    // of the user tweaking zoom or tileSize sliders.
    if (old.image != widget.image) {
      _initialPlacementDone = false;
      return;
    }

    // ── tileSize changed ───────────────────────────────────────
    // The tile grew or shrunk. Keep the current position but
    // re-clamp so the tile doesn't hang off the widget edge.
    // We do NOT reset to center. The user's position is preserved.
    if (old.tileSize != widget.tileSize && _initialPlacementDone) {
      // Clamp synchronously — _widgetSize is always up to date.
      final clamped = _clampToWidget(_tileOffset, _widgetSize, widget.tileSize);
      if (clamped != _tileOffset) {
        // Schedule after current build phase to avoid setState-in-build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _tileOffset = clamped);
        });
      }
    }

    // ── zoomLevel changed ──────────────────────────────────────
    // Nothing to do. The tile position is independent of zoom level.
    // _MagnifierTile reads the new zoomLevel on its next build automatically.
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
        _widgetSize = widgetSize; // keep cached for didUpdateWidget

        // Place tile at center exactly once — on very first layout,
        // or after an image swap. Never called again by zoom/tileSize changes.
        if (!_initialPlacementDone) {
          _tileOffset = widget.initialOffset ??
              Offset(
                (widgetSize.width - widget.tileSize) / 2,
                (widgetSize.height - widget.tileSize) / 2,
              );
          _initialPlacementDone = true;
        }

        return ColoredBox(
          color: widget.backgroundColor,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Layer 1: base image ───────────────────────────
              _BaseImage(
                image: widget.image,
                fit: widget.fit,
                placeholder: widget.placeholder,
                errorWidget: widget.errorWidget,
              ),

              // ── Layer 2: draggable magnifier tile ─────────────
              Positioned(
                left: _tileOffset.dx,
                top: _tileOffset.dy,
                child: GestureDetector(
                  onPanStart: (d) {
                    _dragStartLocal = d.localPosition;
                    _dragStartTile = _tileOffset;
                  },
                  onPanUpdate: (d) {
                    final newOffset = _dragStartTile +
                        (d.localPosition - _dragStartLocal);
                    setState(() {
                      _tileOffset = _clampToWidget(newOffset, _widgetSize, widget.tileSize);
                    });
                    widget.onTilePositionChanged?.call(_tileOffset);
                  },
                  child: _MagnifierTile(
                    image: widget.image,
                    tileOffset: _tileOffset,
                    widgetSize: widgetSize,
                    tileSize: widget.tileSize,
                    zoomLevel: widget.zoomLevel,
                    fit: widget.fit,
                    borderColor: widget.tileBorderColor ??
                        const Color(0xFFEF9F27),
                    borderWidth: widget.tileBorderWidth,
                    borderRadius: widget.tileBorderRadius,
                    elevation: widget.tileElevation,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Clamp tile top-left so it stays fully inside the widget bounds.
  /// Reads [widget.clampTileToImage] — if false, returns [o] unchanged.
  /// Takes [tileSize] explicitly so didUpdateWidget can call it before
  /// widget.tileSize has propagated to the current frame.
  Offset _clampToWidget(Offset o, Size size, double tileSize) {
    if (!widget.clampTileToImage) return o;
    return Offset(
      o.dx.clamp(0.0, math.max(0.0, size.width  - tileSize)),
      o.dy.clamp(0.0, math.max(0.0, size.height - tileSize)),
    );
  }
}

// ─── Magnifier tile ────────────────────────────────────────────────────────────

class _MagnifierTile extends StatelessWidget {
  const _MagnifierTile({
    required this.image,
    required this.tileOffset,
    required this.widgetSize,
    required this.tileSize,
    required this.zoomLevel,
    required this.fit,
    required this.borderColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.elevation,
  });

  final ImageProvider image;
  final Offset tileOffset;       // top-left of tile in widget coords
  final Size widgetSize;
  final double tileSize;
  final double zoomLevel;
  final BoxFit fit;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    // The full image renders at widgetSize inside the base layer.
    // Inside the tile we render the SAME image at (zoomLevel × widgetSize),
    // then translate it so that the region under the tile center is visible.
    //
    // Tile center in widget coords:
    final tileCenterX = tileOffset.dx + tileSize / 2;
    final tileCenterY = tileOffset.dy + tileSize / 2;

    // After scaling by zoomLevel, the image is (widgetSize * zoomLevel).
    // We need to translate so that (tileCenterX * zoomLevel, tileCenterY *
    // zoomLevel) maps to the tile's center (tileSize/2, tileSize/2).
    final tx = tileSize / 2 - tileCenterX * zoomLevel;
    final ty = tileSize / 2 - tileCenterY * zoomLevel;

    return Material(
      elevation: elevation,
      borderRadius: BorderRadius.circular(borderRadius + borderWidth),
      color: Colors.transparent,
      child: Container(
        width: tileSize,
        height: tileSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: elevation * 2,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
              math.max(0, borderRadius - borderWidth)),
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(tx, ty),
              child: SizedBox(
                width: widgetSize.width * zoomLevel,
                height: widgetSize.height * zoomLevel,
                child: Image(
                  image: image,
                  fit: fit,
                  width: widgetSize.width * zoomLevel,
                  height: widgetSize.height * zoomLevel,
                  // FilterQuality.high = bicubic — best pixel quality
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Base image layer ──────────────────────────────────────────────────────────

class _BaseImage extends StatelessWidget {
  const _BaseImage({
    required this.image,
    required this.fit,
    this.placeholder,
    this.errorWidget,
  });

  final ImageProvider image;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (ctx, child, frame, _) =>
      frame == null
          ? (placeholder ??
          const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white38),
          ))
          : child,
      errorBuilder: errorWidget != null
          ? (ctx, _, __) => errorWidget!
          : (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.white38, size: 48),
      ),
    );
  }
}