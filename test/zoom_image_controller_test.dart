import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_image/zoom_image.dart';

void main() {
  group('ZoomImageController', () {
    late ZoomImageController ctrl;
    setUp(() => ctrl = ZoomImageController(minZoom: 1, maxZoom: 5));
    tearDown(() => ctrl.dispose());

    test('initial values', () {
      expect(ctrl.zoom, 1.0);
      expect(ctrl.offset, Offset.zero);
    });

    test('zoomTo clamps to maxZoom', () {
      ctrl.zoomTo(99);
      expect(ctrl.zoom, 5.0);
    });

    test('zoomTo clamps to minZoom', () {
      ctrl.zoomTo(0);
      expect(ctrl.zoom, 1.0);
    });

    test('reset returns to initial state', () {
      ctrl.zoomTo(3);
      ctrl.reset();
      expect(ctrl.zoom, 1.0);
      expect(ctrl.offset, Offset.zero);
    });

    test('fit is alias for reset', () {
      ctrl.zoomTo(3);
      ctrl.fit();
      expect(ctrl.zoom, 1.0);
    });

    test('setZoomRange clamps current zoom', () {
      ctrl.zoomTo(5);
      ctrl.setZoomRange(min: 1, max: 3);
      expect(ctrl.zoom, 3.0);
    });

    test('notifies listeners on zoomTo', () {
      var fired = false;
      ctrl.addListener(() => fired = true);
      ctrl.zoomTo(2);
      expect(fired, isTrue);
    });

    test('doubleTap zooms in when at min', () {
      ctrl.handleDoubleTap(
        tapPosition: const Offset(200, 200),
        widgetSize: const Size(400, 400),
        doubleTapZoom: 2.5,
      );
      expect(ctrl.zoom, closeTo(2.5, 0.01));
    });

    test('doubleTap resets when above min', () {
      ctrl.zoomTo(3);
      ctrl.handleDoubleTap(
        tapPosition: const Offset(200, 200),
        widgetSize: const Size(400, 400),
        doubleTapZoom: 2.5,
      );
      expect(ctrl.zoom, 1.0);
    });
  });

  group('ZoomImageDecoration', () {
    test('toBoxDecoration has matching color', () {
      const dec = ZoomImageDecoration(backgroundColor: Color(0xFF123456));
      expect(dec.toBoxDecoration().color, const Color(0xFF123456));
    });

    test('transparent has zero alpha', () {
      expect(ZoomImageDecoration.transparent.backgroundColor.alpha, 0);
    });
  });

  group('ZoomImage widget', () {
    testWidgets('renders without controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomImage(image: const NetworkImage('https://example.com/img.jpg')),
          ),
        ),
      );
      expect(find.byType(ZoomImage), findsOneWidget);
    });

    testWidgets('renders with external controller', (tester) async {
      final ctrl = ZoomImageController(minZoom: 1, maxZoom: 5);
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomImage(
              image: const NetworkImage('https://example.com/img.jpg'),
              controller: ctrl,
            ),
          ),
        ),
      );
      expect(find.byType(ZoomImage), findsOneWidget);
    });
  });
}