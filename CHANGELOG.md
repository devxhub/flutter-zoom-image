## 0.2.0

* Added `TileZoom` widget — draggable in-place magnifier tile with max pixel quality zoom
* Tile position preserved when `zoomLevel` or `tileSize` changes — only resets on image swap
* `ZoomImage` supports `ZoomImageDecoration` for background, border, border-radius and shadow
* `ZoomImage` supports `ZoomImageControlsStyle` for full control strip customisation
* Renamed barrel file to `flutter_zoom_image.dart` to match package name convention

## 0.1.0

* Initial release
* `ZoomImage` widget with scroll zoom, pinch-to-zoom, pan/drag, double-tap zoom
* `ZoomImageController` for programmatic zoom and pan
* On-screen +/−/reset control strip
* Zoom % badge
* Supports `NetworkImage`, `AssetImage`, `MemoryImage`, `FileImage`
