import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Controls zoom level and pan offset for a [ZoomImage] widget.
///
/// Create one, pass it to [ZoomImage.controller], then call
/// [zoomTo], [panTo], [reset], or [fit] programmatically.
///
/// ```dart
/// final ctrl = ZoomImageController();
///
/// ZoomImage(
///   image: NetworkImage('...'),
///   controller: ctrl,
/// )
///
/// // later:
/// ctrl.zoomTo(3.0);
/// ctrl.reset();
/// ```
class ZoomImageController extends ChangeNotifier {
  ZoomImageController({
    double minZoom = 1.0,
    double maxZoom = 5.0,
    double initialZoom = 1.0,
  })  : _minZoom = minZoom,
        _maxZoom = maxZoom,
        _zoom = initialZoom.clamp(minZoom, maxZoom),
        _offset = Offset.zero;

  double _minZoom;
  double _maxZoom;
  double _zoom;
  Offset _offset;

  double get zoom => _zoom;
  Offset get offset => _offset;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  /// Update allowed zoom range at runtime; clamps current zoom if needed.
  void setZoomRange({required double min, required double max}) {
    assert(min > 0 && max >= min);
    _minZoom = min;
    _maxZoom = max;
    _zoom = _zoom.clamp(_minZoom, _maxZoom);
    notifyListeners();
  }

  /// Zoom to [level], optionally keeping [focalPoint] fixed on screen.
  void zoomTo(double level, {Offset? focalPoint, Size? widgetSize}) {
    final newZoom = level.clamp(_minZoom, _maxZoom);
    if (widgetSize != null && focalPoint != null) {
      _offset = _shiftForZoom(
          oldZoom: _zoom, newZoom: newZoom, focal: focalPoint);
    }
    _zoom = newZoom;
    notifyListeners();
  }

  /// Pan so [imagePoint] (in image-pixel coords) is centered in the widget.
  void panTo(Offset imagePoint, Size widgetSize) {
    _offset = Offset(
      widgetSize.width / 2 - imagePoint.dx * _zoom,
      widgetSize.height / 2 - imagePoint.dy * _zoom,
    );
    _clamp(widgetSize);
    notifyListeners();
  }

  /// Reset to [minZoom] and center the image.
  void reset() {
    _zoom = _minZoom;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Alias for [reset].
  void fit() => reset();

  // ── Internal ──────────────────────────────────────────────────────────────

  void applyScaleUpdate({
    required double scaleDelta,
    required Offset focalPoint,
    required Offset panDelta,
    required Size widgetSize,
  }) {
    final newZoom = (_zoom * scaleDelta).clamp(_minZoom, _maxZoom);
    _offset = _shiftForZoom(oldZoom: _zoom, newZoom: newZoom, focal: focalPoint);
    _zoom = newZoom;
    _offset += panDelta;
    _clamp(widgetSize);
    notifyListeners();
  }

  void handleDoubleTap({
    required Offset tapPosition,
    required Size widgetSize,
    double doubleTapZoom = 2.5,
  }) {
    if (_zoom > _minZoom + 0.01) {
      reset();
    } else {
      zoomTo(doubleTapZoom, focalPoint: tapPosition, widgetSize: widgetSize);
    }
  }

  Offset _shiftForZoom({
    required double oldZoom,
    required double newZoom,
    required Offset focal,
  }) {
    final scale = newZoom / (oldZoom == 0 ? 1 : oldZoom);
    return focal - (focal - _offset) * scale;
  }

  void _clamp(Size widgetSize) {
    if (_zoom <= _minZoom) { _offset = Offset.zero; return; }
    final ex = math.max(0.0, widgetSize.width * (_zoom - 1) / 2);
    final ey = math.max(0.0, widgetSize.height * (_zoom - 1) / 2);
    _offset = Offset(_offset.dx.clamp(-ex, ex), _offset.dy.clamp(-ey, ey));
  }

  Matrix4 get transform => Matrix4.identity()
    ..translate(_offset.dx, _offset.dy)
    ..scale(_zoom);
}