import 'package:flutter/material.dart';
import '../flutter_zoom_image.dart';
import 'zoom_image_controller.dart';


// Internal — not exported.
class ZoomControlsOverlay extends StatelessWidget {
  const ZoomControlsOverlay({
    super.key,
    required this.controller,
    required this.widgetSize,
    required this.style,
  });

  final ZoomImageController controller;
  final Size widgetSize;
  final ZoomImageControlsStyle style;

  void _zoom(double delta) {
    controller.zoomTo(
      controller.zoom + delta,
      focalPoint: Offset(widgetSize.width / 2, widgetSize.height / 2),
      widgetSize: widgetSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = style.backgroundColor ??
        Theme.of(context).colorScheme.surface.withOpacity(0.85);
    final fg = style.iconColor ?? Theme.of(context).colorScheme.onSurface;
    final radius = style.borderRadius ?? BorderRadius.circular(10);

    return Align(
      alignment: style.alignment,
      child: Padding(
        padding: style.padding,
        child: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Btn(
                  icon: Icons.add,
                  size: style.buttonSize,
                  color: fg,
                  enabled: controller.zoom < controller.maxZoom,
                  onTap: () => _zoom(style.zoomStep),
                  tooltip: 'Zoom in',
                ),
                Divider(height: 0.5, thickness: 0.5, color: fg.withOpacity(0.15)),
                _Btn(
                  icon: Icons.remove,
                  size: style.buttonSize,
                  color: fg,
                  enabled: controller.zoom > controller.minZoom,
                  onTap: () => _zoom(-style.zoomStep),
                  tooltip: 'Zoom out',
                ),
                Divider(height: 0.5, thickness: 0.5, color: fg.withOpacity(0.15)),
                _Btn(
                  icon: Icons.fit_screen_outlined,
                  size: style.buttonSize,
                  color: fg,
                  enabled: true,
                  onTap: controller.reset,
                  tooltip: 'Reset',
                ),
              ],
            ),
          ),
        ),
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
  Widget build(BuildContext context) => Tooltip(
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