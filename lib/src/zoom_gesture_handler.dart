import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'zoom_image_controller.dart';

// Internal widget — not exported from the package barrel.
class ZoomGestureHandler extends StatefulWidget {
  const ZoomGestureHandler({
    super.key,
    required this.controller,
    required this.child,
    this.doubleTapZoom = 2.5,
    this.scrollSensitivity = 0.001,
    this.onZoomChanged,
    this.onPanChanged,
  });

  final ZoomImageController controller;
  final Widget child;
  final double doubleTapZoom;
  final double scrollSensitivity;
  final ValueChanged<double>? onZoomChanged;
  final ValueChanged<Offset>? onPanChanged;

  @override
  State<ZoomGestureHandler> createState() => _State();
}

class _State extends State<ZoomGestureHandler> {
  double _startZoom = 1.0;
  Offset _lastFocal = Offset.zero;
  Size get _size {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size ?? Size.zero;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startZoom = widget.controller.zoom;
    _lastFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final size = _size;
    if (size == Size.zero) return;
    final panDelta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;

    final targetZoom = (_startZoom * d.scale)
        .clamp(widget.controller.minZoom, widget.controller.maxZoom);
    final effectiveScale = targetZoom / widget.controller.zoom;

    widget.controller.applyScaleUpdate(
      scaleDelta: effectiveScale,
      focalPoint: d.localFocalPoint,
      panDelta: panDelta,
      widgetSize: size,
    );
    widget.onZoomChanged?.call(widget.controller.zoom);
    widget.onPanChanged?.call(widget.controller.offset);
  }

  void _onScaleEnd(ScaleEndDetails d) {}

  void _onDoubleTap() {
    widget.controller.handleDoubleTap(
      tapPosition: _lastFocal,
      widgetSize: _size,
      doubleTapZoom: widget.doubleTapZoom,
    );
    widget.onZoomChanged?.call(widget.controller.zoom);
    widget.onPanChanged?.call(widget.controller.offset);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final size = _size;
      if (size == Size.zero) return;
      final delta = 1.0 - event.scrollDelta.dy * widget.scrollSensitivity;
      widget.controller.applyScaleUpdate(
        scaleDelta: delta,
        focalPoint: event.localPosition,
        panDelta: Offset.zero,
        widgetSize: size,
      );
      widget.onZoomChanged?.call(widget.controller.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        child: RawGestureDetector(
          gestures: {
            ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
              ScaleGestureRecognizer.new,
                  (i) => i
                ..onStart = _onScaleStart
                ..onUpdate = _onScaleUpdate
                ..onEnd = _onScaleEnd,
            ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}