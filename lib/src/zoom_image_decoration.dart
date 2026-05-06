import 'package:flutter/widgets.dart';

/// Visual decoration applied to the [ZoomImage] container.
///
/// Controls the background, border, border-radius, and shadow drawn
/// *behind* the image — similar to [BoxDecoration] for a [Container].
///
/// ```dart
/// ZoomImage(
///   image: NetworkImage('...'),
///   decoration: ZoomImageDecoration(
///     backgroundColor: Colors.grey.shade900,
///     borderRadius: BorderRadius.circular(16),
///     border: Border.all(color: Colors.white12),
///     boxShadow: [BoxShadow(blurRadius: 24, color: Colors.black54)],
///   ),
/// )
/// ```
class ZoomImageDecoration {
  const ZoomImageDecoration({
    this.backgroundColor = const Color(0xFF000000),
    this.borderRadius,
    this.border,
    this.boxShadow,
  });

  /// Color rendered behind the image (visible when image doesn't fill widget).
  final Color backgroundColor;

  /// Rounds the corners of the whole widget.
  final BorderRadiusGeometry? borderRadius;

  /// Border drawn around the widget edge.
  final BoxBorder? border;

  /// Shadows cast by the widget.
  final List<BoxShadow>? boxShadow;

  /// Equivalent to [ZoomImageDecoration()] with a transparent background.
  static const transparent = ZoomImageDecoration(
    backgroundColor: Color(0x00000000),
  );

  BoxDecoration toBoxDecoration() => BoxDecoration(
    color: backgroundColor,
    borderRadius: borderRadius,
    border: border,
    boxShadow: boxShadow,
  );

  @override
  bool operator ==(Object other) =>
      other is ZoomImageDecoration &&
          other.backgroundColor == backgroundColor &&
          other.borderRadius == borderRadius &&
          other.border == border;

  @override
  int get hashCode =>
      Object.hash(backgroundColor, borderRadius, border);
}