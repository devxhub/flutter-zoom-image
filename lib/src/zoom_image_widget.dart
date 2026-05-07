import 'package:flutter/material.dart';
import '../flutter_zoom_image.dart';
import 'zoom_controller.dart';
import 'zoom_gesture_handler.dart';




/// A full-featured interactive image zoom widget.
///
/// ## Core features
/// - **Scroll zoom** — mouse wheel on desktop/web
/// - **Pinch-to-zoom** — two-finger pinch on touch devices
/// - **Pan / drag** — single-finger or click-and-drag to move
/// - **Double-tap zoom** — toggles between fit and [doubleTapZoom]
/// - **Zoom controls** — on-screen +/− and reset buttons (optional)
/// - **Min/max zoom limits** — enforced by [ZoomImageController]
///
/// ## Basic usage
/// ```dart
/// ZoomImageWidget(
///   image: NetworkImage('https://example.com/photo.jpg'),
///   minZoom: 1,
///   maxZoom: 8,
/// )
/// ```
///
/// ## Programmatic control
/// ```dart
/// final ctrl = ZoomImageController(minZoom: 1, maxZoom: 8);
///
/// ZoomImageWidget(
///   image: const AssetImage('images/map.png'),
///   controller: ctrl,
/// )
///
/// // Later:
/// ctrl.zoomTo(3.0);
/// ctrl.reset();
/// ```
class ZoomImageWidget extends StatefulWidget {
  const ZoomImageWidget({
    super.key,
    required this.image,
    this.controller,
    this.minZoom = 1.0,
    this.maxZoom = 5.0,
    this.initialZoom = 1.0,
    this.doubleTapZoom = 2.5,
    this.scrollSensitivity = 0.001,
    this.showControls = true,
    this.controlsAlignment = Alignment.bottomRight,
    this.controlsPadding = const EdgeInsets.all(12),
    this.backgroundColor = Colors.black,
    this.fit = BoxFit.contain,
    this.clipBehavior = Clip.hardEdge,
    this.onZoomChanged,
    this.onPanChanged,
    this.placeholder,
    this.errorWidget,
  });

  // ─── Image source ─────────────────────────────────────────────────────────

  /// The image to display. Accepts any [ImageProvider]:
  /// [NetworkImage], [AssetImage], [MemoryImage], etc.
  final ImageProvider image;

  // ─── Controller ───────────────────────────────────────────────────────────

  /// Optional external controller. If null, an internal one is created using
  /// [minZoom], [maxZoom], and [initialZoom].
  final ZoomImageController? controller;

  // ─── Zoom bounds ──────────────────────────────────────────────────────────

  /// Minimum zoom level (default 1 = fit-to-widget).
  final double minZoom;

  /// Maximum zoom level (default 5).
  final double maxZoom;

  /// Starting zoom level (default 1).
  final double initialZoom;

  // ─── Interaction ──────────────────────────────────────────────────────────

  /// Zoom level reached on double-tap (when currently at minZoom).
  final double doubleTapZoom;

  /// Scroll-wheel sensitivity (0.001 feels natural).
  final double scrollSensitivity;

  // ─── Controls UI ─────────────────────────────────────────────────────────

  /// Show the +/− / reset button strip.
  final bool showControls;

  /// Position of the controls strip.
  final AlignmentGeometry controlsAlignment;

  /// Padding around the controls strip.
  final EdgeInsetsGeometry controlsPadding;

  // ─── Appearance ───────────────────────────────────────────────────────────

  /// Background color shown outside the image.
  final Color backgroundColor;

  /// How the image fits inside its bounds (default [BoxFit.contain]).
  final BoxFit fit;

  /// Clip behavior for the zoomed image (default [Clip.hardEdge]).
  final Clip clipBehavior;

  // ─── Callbacks ───────────────────────────────────────────────────────────

  /// Triggered whenever the zoom level changes.
  final ValueChanged<double>? onZoomChanged;

  /// Triggered whenever the pan offset changes.
  final ValueChanged<Offset>? onPanChanged;

  // ─── Loading / error ─────────────────────────────────────────────────────

  /// Widget shown while the image loads (defaults to a centered spinner).
  final Widget? placeholder;

  /// Widget shown if the image fails to load.
  final WidgetBuilder? errorWidget;

  @override
  State<ZoomImageWidget> createState() => _ZoomImageWidgetState();
}

class _ZoomImageWidgetState extends State<ZoomImageWidget> {
  late ZoomImageController _ctrl;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _ctrl = widget.controller!;
      _ownsController = false;
    } else {
      _ctrl = ZoomImageController(
        minZoom: widget.minZoom,
        maxZoom: widget.maxZoom,
        initialZoom: widget.initialZoom,
      );
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(ZoomImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _ctrl.dispose();
      _initController();
    }
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return ClipRect(
          clipBehavior: widget.clipBehavior,
          child: ColoredBox(
            color: widget.backgroundColor,
            child: ZoomGestureHandler(
              controller: _ctrl,
              doubleTapZoom: widget.doubleTapZoom,
              scrollSensitivity: widget.scrollSensitivity,
              onZoomChanged: widget.onZoomChanged,
              onPanChanged: widget.onPanChanged,
              child: Stack(
                children: [
                  // ── Zoomed image ──────────────────────────────────────────
                  _ZoomedImage(
                    controller: _ctrl,
                    image: widget.image,
                    fit: widget.fit,
                    placeholder: widget.placeholder,
                    errorWidget: widget.errorWidget,
                  ),

                  // ── Zoom controls overlay ─────────────────────────────────
                  if (widget.showControls)
                    ZoomControls(
                      controller: _ctrl,
                      widgetSize: size,
                      alignment: widget.controlsAlignment as Alignment,
                      padding: widget.controlsPadding,
                    ),

                  // ── Zoom-level indicator (top-left) ───────────────────────
                  _ZoomIndicator(controller: _ctrl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Zoomed image layer ────────────────────────────────────────────────────────

class _ZoomedImage extends StatelessWidget {
  const _ZoomedImage({
    required this.controller,
    required this.image,
    required this.fit,
    this.placeholder,
    this.errorWidget,
  });

  final ZoomImageController controller;
  final ImageProvider image;
  final BoxFit fit;
  final Widget? placeholder;
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) => Transform(
        transform: controller.transform,
        child: Image(
          image: image,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (ctx, child, frame, _) =>
          frame == null ? (placeholder ?? const _DefaultPlaceholder()) : child,
          errorBuilder: errorWidget != null
              ? (ctx, _, __) => errorWidget!(ctx)
              : (_, __, ___) => const _DefaultError(),
        ),
      ),
    );
  }
}

// ─── Zoom level text indicator ─────────────────────────────────────────────────

class _ZoomIndicator extends StatelessWidget {
  const _ZoomIndicator({required this.controller});
  final ZoomImageController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, __) {
          final pct = (controller.zoom * 100).round();
          return AnimatedOpacity(
            opacity: controller.zoom > controller.minZoom + 0.05 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Default placeholder / error widgets ──────────────────────────────────────

class _DefaultPlaceholder extends StatelessWidget {
  const _DefaultPlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(strokeWidth: 2),
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
            size: 48, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text(
          'Failed to load image',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
        ),
      ],
    ),
  );
}