import 'package:flutter/material.dart';
import 'package:flutter_zoom_image/zoom_image.dart';


void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_zoom_image demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('flutter_zoom_image'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Tile Zoom'),
            Tab(text: 'Standard'),
            Tab(text: 'Styled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_TileZoomExample(), _StandardExample(), _StyledExample()],
      ),
    );
  }
}

// ── Tab 1: TileZoom ───────────────────────────────────────────────────────────

class _TileZoomExample extends StatefulWidget {
  const _TileZoomExample();
  @override
  State<_TileZoomExample> createState() => _TileZoomExampleState();
}

class _TileZoomExampleState extends State<_TileZoomExample> {
  double _zoom = 4.0;
  double _tileSize = 120.0;
  Offset _tilePos = Offset.zero;
  int _imgIdx = 0;

  static const _images = [
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=2000',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=2000',
    'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=2000',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: TileZoom(
          image: NetworkImage(_images[_imgIdx]),
          zoomLevel: _zoom,
          tileSize: _tileSize,
          fit: BoxFit.contain,
          backgroundColor: Colors.black,
          tileBorderColor: const Color(0xFFEF9F27),
          tileBorderWidth: 2.0,
          tileBorderRadius: 8.0,
          clampTileToImage: true,
          onTilePositionChanged: (o) => setState(() => _tilePos = o),
        ),
      ),
      Container(
        color: Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat('Zoom', '${_zoom.toStringAsFixed(1)}×'),
            _Stat('Tile', '${_tileSize.round()}px'),
            _Stat('X', _tilePos.dx.toStringAsFixed(0)),
            _Stat('Y', _tilePos.dy.toStringAsFixed(0)),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          const Text('Zoom  ', style: TextStyle(fontSize: 12, color: Colors.white54)),
          Expanded(
            child: Slider(
              value: _zoom, min: 1.5, max: 8.0, divisions: 13,
              label: '${_zoom.toStringAsFixed(1)}×',
              onChanged: (v) => setState(() => _zoom = v),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(children: [
          const Text('Tile  ', style: TextStyle(fontSize: 12, color: Colors.white54)),
          Expanded(
            child: Slider(
              value: _tileSize, min: 60, max: 220, divisions: 16,
              label: '${_tileSize.round()}px',
              onChanged: (v) => setState(() => _tileSize = v),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(children: [
          _Btn('Next image', () => setState(() => _imgIdx = (_imgIdx + 1) % _images.length)),
        ]),
      ),
    ]);
  }
}

// ── Tab 2: ZoomImage standard ─────────────────────────────────────────────────

class _StandardExample extends StatefulWidget {
  const _StandardExample();
  @override
  State<_StandardExample> createState() => _StandardExampleState();
}

class _StandardExampleState extends State<_StandardExample> {
  final _ctrl = ZoomImageController(minZoom: 1, maxZoom: 8);
  double _zoom = 1;
  Offset _pan = Offset.zero;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ZoomImage(
          image: const NetworkImage(
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=2000',
          ),
          controller: _ctrl,
          minZoom: 1,
          maxZoom: 8,
          doubleTapZoom: 3,
          showControls: true,
          showZoomBadge: true,
          decoration: const ZoomImageDecoration(backgroundColor: Colors.black),
          onZoomChanged: (z) => setState(() => _zoom = z),
          onPanChanged: (o) => setState(() => _pan = o),
        ),
      ),
      Container(
        color: Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _Stat('Zoom', '${(_zoom * 100).round()}%'),
          _Stat('Pan X', '${_pan.dx.toStringAsFixed(1)}px'),
          _Stat('Pan Y', '${_pan.dy.toStringAsFixed(1)}px'),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          const Text('API:', style: TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(width: 8),
          _Btn('1×', () => _ctrl.zoomTo(1)),
          _Btn('2×', () => _ctrl.zoomTo(2)),
          _Btn('4×', () => _ctrl.zoomTo(4)),
          _Btn('Reset', _ctrl.reset),
        ]),
      ),
    ]);
  }
}

// ── Tab 3: Styled ZoomImage ───────────────────────────────────────────────────

class _StyledExample extends StatelessWidget {
  const _StyledExample();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          height: 420,
          child: ZoomImage(
            image: const NetworkImage(
              'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=2000',
            ),
            minZoom: 1,
            maxZoom: 6,
            doubleTapZoom: 2,
            decoration: ZoomImageDecoration(
              backgroundColor: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 12)),
              ],
            ),
            showControls: true,
            controlsStyle: const ZoomImageControlsStyle(
              alignment: Alignment.bottomLeft,
              padding: EdgeInsets.all(16),
              buttonSize: 42,
              backgroundColor: Color(0xDD1A1A2E),
              iconColor: Colors.white,
              zoomStep: 0.75,
            ),
            showZoomBadge: true,
          ),
        ),
      ),
    );
  }
}

// ── Shared UI ─────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label; final String value;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
    const SizedBox(height: 2),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
  ]);
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onTap);
  final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Colors.white24),
        foregroundColor: Colors.white70, textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    ),
  );
}