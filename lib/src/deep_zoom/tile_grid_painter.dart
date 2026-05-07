import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../zoom_image_controller.dart';
import 'dzi_descriptor.dart';
import 'tile_loader.dart';

/// A [CustomPainter] that renders the Deep Zoom tile grid.
///
/// For each visible tile it either:
/// - Draws the cached [ui.Image] directly, OR
/// - Falls back to a lower-resolution tile from a parent level.
///
/// The fallback strategy gives the "blurry → sharp" progressive reveal that
/// is characteristic of Deep Zoom viewers like OpenSeadragon.
class TileGridPainter extends CustomPainter {
  TileGridPainter({
    required this.descriptor,
    required this.loader,
    required this.controller,
  }) : super(repaint: Listenable.merge([loader, controller]));

  final DziDescriptor descriptor;
  final TileLoader loader;
  final ZoomImageController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final zoom = controller.zoom;
    final offset = controller.offset;

    // Choose the pyramid level that matches current zoom.
    final level = descriptor.bestLevel(zoom, size);

    // Scale factor: how many screen pixels per level-pixel.
    final levelScale = zoom / math.pow(2, descriptor.maxLevel - level);
    final tileScreenSize = descriptor.tileSize * levelScale;

    // Compute visible tile range.
    final cols = descriptor.colsAtLevel(level);
    final rows = descriptor.rowsAtLevel(level);

    final x0 = (-offset.dx / tileScreenSize).floor().clamp(0, cols - 1);
    final y0 = (-offset.dy / tileScreenSize).floor().clamp(0, rows - 1);
    final x1 = ((size.width - offset.dx) / tileScreenSize).ceil().clamp(0, cols - 1);
    final y1 = ((size.height - offset.dy) / tileScreenSize).ceil().clamp(0, rows - 1);

    final paint = Paint()..filterQuality = FilterQuality.medium;

    // Collect tiles to prefetch neighbors.
    final toLoad = <TileId>[];

    for (var row = y0; row <= y1; row++) {
      for (var col = x0; col <= x1; col++) {
        final tile = TileId(level: level, col: col, row: row);

        // Screen rectangle where this tile should appear.
        final dst = Rect.fromLTWH(
          offset.dx + col * tileScreenSize,
          offset.dy + row * tileScreenSize,
          tileScreenSize,
          tileScreenSize,
        );

        final img = loader.getTile(tile);
        if (img != null) {
          _drawTile(canvas, img, dst, paint);
        } else {
          // Fallback: try parent levels (coarser) for a blurry placeholder.
          _drawFallback(canvas, paint, level, col, row, dst);
          toLoad.add(tile);
        }
      }
    }

    // Prefetch neighbor tiles (one ring around the visible area).
    if (loader.prefetchNeighbors) {
      _prefetchNeighbors(level, x0, y0, x1, y1, cols, rows);
    }
  }

  void _drawTile(Canvas canvas, ui.Image img, Rect dst, Paint paint) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, dst, paint);
  }

  /// Walk up the pyramid to find a coarser tile that covers the same area.
  void _drawFallback(
      Canvas canvas,
      Paint paint,
      int level,
      int col,
      int row,
      Rect dst,
      ) {
    for (var parentLevel = level - 1; parentLevel >= 0; parentLevel--) {
      // At each level up, tile indices halve.
      final steps = level - parentLevel;
      final factor = math.pow(2, steps).toInt();
      final pCol = col ~/ factor;
      final pRow = row ~/ factor;

      final parentTile = TileId(level: parentLevel, col: pCol, row: pRow);
      final img = loader.getTile(parentTile);
      if (img == null) continue;

      // Fraction of the parent tile that this child covers.
      final srcW = img.width / factor.toDouble();
      final srcH = img.height / factor.toDouble();
      final srcX = (col % factor) * srcW;
      final srcY = (row % factor) * srcH;

      final src = Rect.fromLTWH(srcX, srcY, srcW, srcH);

      canvas.drawImageRect(img, src, dst, paint
        ..filterQuality = FilterQuality.low);
      return; // drew something — stop walking up
    }
  }

  void _prefetchNeighbors(
      int level, int x0, int y0, int x1, int y1, int cols, int rows) {
    final neighbors = <TileId>[];
    for (var row = (y0 - 1).clamp(0, rows - 1);
    row <= (y1 + 1).clamp(0, rows - 1);
    row++) {
      for (var col = (x0 - 1).clamp(0, cols - 1);
      col <= (x1 + 1).clamp(0, cols - 1);
      col++) {
        if (row < y0 || row > y1 || col < x0 || col > x1) {
          neighbors.add(TileId(level: level, col: col, row: row));
        }
      }
    }
    if (neighbors.isNotEmpty) loader.prefetch(neighbors);
  }

  @override
  bool shouldRepaint(TileGridPainter oldDelegate) => true;
}