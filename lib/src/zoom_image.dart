import 'package:flutter/material.dart';


import '../flutter_zoom_image.dart';
import 'zoom_image_controller.dart';
import 'zoom_image_decoration.dart';
import 'zoom_gesture_handler.dart';
import 'zoom_controls_overlay.dart';

/// An interactive image zoom widget.
///
/// Supports any [ImageProvider] — Network, Asset, Memory, File.
///
/// ## Features
/// - Scroll zoom (mouse wheel)
/// - Pinch-to-zoom (touch / trackpad)
/// - Pan / drag
/// - Double-tap zoom toggle
/// - On-screen +/−/reset controls
/// - Configurable min / max zoom limits
/// - Programmatic [ZoomImageController] API
///
/// ## Usage
/// ```dart
/// // Network
/// ZoomImage(
///   image: NetworkImage('https://example.com/photo.jpg'),
/// )
///
/// // Asset
/// ZoomImage(
///   image: AssetImage('images/images/photo.jpg'),
/// )
///
/// // With full options
/// ZoomImage(
///   image: NetworkImage('https://...'),
///   controller: _ctrl,
///   minZoom: 1.0,
///   maxZoom: 8.0,
///   doubleTapZoom: 3.0,
///   showControls: true,
///   showZoomBadge: true,
///   decoration: ZoomImageDecoration(
///     backgroundColor: Colors.black,
///     borderRadius: BorderRadius.circular(16),
///   ),
///   controlsStyle: ZoomImageControlsStyle(
///     alignment: Alignment.bottomRight,
///     buttonSize: 36,
///   ),
///   onZoomChanged: (zoom) => print(zoom),
///   onPanChanged: (offset) => print(offset),
/// )
/// ```
class ZoomImage extends StatefulWidget {
  const ZoomImage({
    super.key,
    required this.image,
    this.controller,
    this.minZoom = 1.0,
    this.maxZoom = 5.0,
    this.initialZoom = 1.0,
    this.doubleTapZoom = 2.5,
    this.scrollSensitivity = 0.001,
    this.fit = BoxFit.contain,
    this.decoration = const ZoomImageDecoration(),
    this.showControls = true,
    this.controlsStyle = const ZoomImageControlsStyle(),
    this.showZoomBadge = true,
    this.clipBehavior = Clip.hardEdge,
    this.onZoomChanged,
    this.onPanChanged,
    this.placeholder,
    this.errorWidget,
  });

  /// The image source. Accepts any [ImageProvider]:
  /// [NetworkImage], [AssetImage], [MemoryImage], [FileImage].
  final ImageProvider image;

  /// Optional external controller for programmatic zoom/pan.
  /// If null, the widget creates and manages its own controller.
  final ZoomImageController? controller;

  /// Minimum zoom level — image cannot shrink below this. Default 1.0.
  final double minZoom;

  /// Maximum zoom level — image cannot grow beyond this. Default 5.0.
  final double maxZoom;

  /// Zoom level when the widget first renders. Default 1.0.
  final double initialZoom;

  /// Zoom level reached on double-tap (when at [minZoom]). Default 2.5.
  final double doubleTapZoom;

  /// Mouse scroll-wheel zoom sensitivity. Default 0.001.
  final double scrollSensitivity;

  /// How the image fits inside the widget bounds. Default [BoxFit.contain].
  final BoxFit fit;

  /// Background color, border, border-radius and shadow for the widget.
  final ZoomImageDecoration decoration;

  /// Whether to show the on-screen +/−/reset control strip. Default true.
  final bool showControls;

  /// Visual style for the control strip — position, size, colors.
  final ZoomImageControlsStyle controlsStyle;

  /// Whether to show the current zoom % badge in the top-left. Default true.
  final bool showZoomBadge;

  /// Clip behavior for the zoomed content. Default [Clip.hardEdge].
  final Clip clipBehavior;

  /// Called every time the zoom level changes.
  final ValueChanged<double>? onZoomChanged;

  /// Called every time the pan offset changes.
  final ValueChanged<Offset>? onPanChanged;

  /// Widget shown while the image is loading. Defaults to a spinner.
  final Widget? placeholder;

  /// Widget shown when the image fails to load. Defaults to a broken-image icon.
  final Widget? errorWidget;

  @override
  State<ZoomImage> createState() => _ZoomImageState();
}

class _ZoomImageState extends State<ZoomImage> {
  late ZoomImageController _ctrl;
  bool _ownsCtrl = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _ctrl = widget.controller!;
      _ownsCtrl = false;
    } else {
      _ctrl = ZoomImageController(
        minZoom: widget.minZoom,
        maxZoom: widget.maxZoom,
        initialZoom: widget.initialZoom,
      );
      _ownsCtrl = true;
    }
  }

  @override
  void didUpdateWidget(ZoomImage old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (_ownsCtrl) _ctrl.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    if (_ownsCtrl) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Container(
          decoration: widget.decoration.toBoxDecoration(),
          clipBehavior: widget.clipBehavior,
          child: ZoomGestureHandler(
            controller: _ctrl,
            doubleTapZoom: widget.doubleTapZoom,
            scrollSensitivity: widget.scrollSensitivity,
            onZoomChanged: widget.onZoomChanged,
            onPanChanged: widget.onPanChanged,
            child: Stack(
              children: [
                // ── Zoomed image ──────────────────────────────────
                _ImageLayer(
                  image: widget.image,
                  ctrl: _ctrl,
                  fit: widget.fit,
                  placeholder: widget.placeholder,
                  errorWidget: widget.errorWidget,
                ),

                // ── +/−/reset controls ────────────────────────────
                if (widget.showControls)
                  ZoomControlsOverlay(
                    controller: _ctrl,
                    widgetSize: size,
                    style: widget.controlsStyle,
                  ),

                // ── Zoom % badge ──────────────────────────────────
                if (widget.showZoomBadge) _ZoomBadge(ctrl: _ctrl),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Image layer ───────────────────────────────────────────────────────────────

class _ImageLayer extends StatelessWidget {
  const _ImageLayer({
    required this.image,
    required this.ctrl,
    required this.fit,
    this.placeholder,
    this.errorWidget,
  });

  final ImageProvider image;
  final ZoomImageController ctrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (_, __) => Transform(
        transform: ctrl.transform,
        child: Image(
          image: image,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          frameBuilder: (ctx, child, frame, _) =>
          frame == null
              ? (placeholder ?? const _DefaultPlaceholder())
              : child,
          errorBuilder: errorWidget != null
              ? (ctx, _, __) => errorWidget!
              : (_, __, ___) => const _DefaultError(),
        ),
      ),
    );
  }
}

// ─── Zoom % badge ───────────────────────────────────────────────────────────────

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({required this.ctrl});
  final ZoomImageController ctrl;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      child: ListenableBuilder(
        listenable: ctrl,
        builder: (_, __) => AnimatedOpacity(
          opacity: ctrl.zoom > ctrl.minZoom + 0.05 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(ctrl.zoom * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Default placeholder / error ───────────────────────────────────────────────

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
  );
}

class _DefaultError extends StatelessWidget {
  const _DefaultError();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined,
            size: 48, color: Colors.white.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text(
          'Failed to load image',
          style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    ),
  );
}