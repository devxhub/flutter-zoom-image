import 'package:flutter/material.dart';
import 'zoom_image_controller.dart';

/// An overlay with +, −, and reset buttons that drive [controller].
///
/// Designed to sit inside a [Stack] on top of the image.
class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.controller,
    required this.widgetSize,
    this.zoomStep = 0.5,
    this.alignment = Alignment.bottomRight,
    this.padding = const EdgeInsets.all(12),
    this.buttonSize = 36,
    this.backgroundColor,
    this.iconColor,
  });

  final ZoomImageController controller;

  /// The size of the parent widget — needed for clamping after zoom.
  final Size widgetSize;

  /// How much each +/− tap changes the zoom level.
  final double zoomStep;

  /// Where the control strip is positioned inside the parent [Stack].
  final AlignmentGeometry alignment;

  final EdgeInsetsGeometry padding;
  final double buttonSize;
  final Color? backgroundColor;
  final Color? iconColor;

  void _zoom(double delta) {
    controller.zoomTo(
      controller.zoom + delta,
      focalPoint: Offset(widgetSize.width / 2, widgetSize.height / 2),
      widgetSize: widgetSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ??
        Theme.of(context).colorScheme.surface.withOpacity(0.85);
    final fg = iconColor ?? Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => _ControlStrip(
            bg: bg,
            fg: fg,
            buttonSize: buttonSize,
            canZoomIn: controller.zoom < controller.maxZoom,
            canZoomOut: controller.zoom > controller.minZoom,
            onZoomIn: () => _zoom(zoomStep),
            onZoomOut: () => _zoom(-zoomStep),
            onReset: controller.reset,
          ),
        ),
      ),
    );
  }
}

class _ControlStrip extends StatelessWidget {
  const _ControlStrip({
    required this.bg,
    required this.fg,
    required this.buttonSize,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final Color bg;
  final Color fg;
  final double buttonSize;
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(
            icon: Icons.add,
            size: buttonSize,
            color: fg,
            enabled: canZoomIn,
            onTap: onZoomIn,
            tooltip: 'Zoom in',
          ),
          Divider(height: 0.5, thickness: 0.5, color: fg.withOpacity(0.15)),
          _Btn(
            icon: Icons.remove,
            size: buttonSize,
            color: fg,
            enabled: canZoomOut,
            onTap: onZoomOut,
            tooltip: 'Zoom out',
          ),
          Divider(height: 0.5, thickness: 0.5, color: fg.withOpacity(0.15)),
          _Btn(
            icon: Icons.fit_screen_outlined,
            size: buttonSize,
            color: fg,
            enabled: true,
            onTap: onReset,
            tooltip: 'Reset',
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.size,
    required this.color,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final double size;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: enabled ? color : color.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}