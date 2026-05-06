import 'package:flutter/widgets.dart';

/// Configures the appearance and position of the on-screen zoom controls
/// (+, −, reset) shown inside a [ZoomImage].
///
/// Pass an instance to [ZoomImage.controlsStyle] to customise the controls,
/// or set [ZoomImage.showControls] = false to hide them entirely.
///
/// ```dart
/// ZoomImage(
///   image: NetworkImage('...'),
///   showControls: true,
///   controlsStyle: ZoomImageControlsStyle(
///     alignment: Alignment.bottomLeft,
///     padding: EdgeInsets.all(16),
///     buttonSize: 40,
///     backgroundColor: Colors.black87,
///     iconColor: Colors.white,
///   ),
/// )
/// ```
class ZoomImageControlsStyle {
  const ZoomImageControlsStyle({
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.all(12),
    this.buttonSize = 36.0,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
    this.zoomStep = 0.5,
  });

  /// Where the control strip is placed inside the widget.
  final AlignmentGeometry alignment;

  /// Padding between the widget edge and the control strip.
  final EdgeInsetsGeometry padding;

  /// Width and height of each button in the strip.
  final double buttonSize;

  /// Background of the control strip container.
  /// Defaults to the theme's surface color at 85 % opacity.
  final Color? backgroundColor;

  /// Icon color for +, −, reset. Defaults to theme's onSurface.
  final Color? iconColor;

  /// Corner radius of the control strip container.
  final BorderRadiusGeometry? borderRadius;

  /// How much zoom changes per +/− tap.
  final double zoomStep;
}