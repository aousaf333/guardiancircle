import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Tile coordinates parsed from a tile URL.
typedef TileCoords = ({int z, int x, int y});

/// On-disk cache for map tile images, keyed by tile URL.
///
/// Tiles fetched while online are written to the app support directory so
/// they can be served again later when there is no internet connection. The
/// cache is best-effort: every failure is logged and swallowed so that tile
/// rendering never breaks.
///
/// Only tiles whose zoom level falls within [minCachedZoom] and
/// [maxCachedZoom] are stored. Tiles are cached per zoom level and reads
/// never fall back to a different zoom level, so the offline map never has to
/// upscale a lower-resolution tile to stand in for a missing one.
///
/// Usage:
/// ```dart
/// final bytes = await MapTileCacheService.instance.readTile(url);
/// if (bytes != null) { /* render cached tile */ }
/// await MapTileCacheService.instance.writeTile(url, bytes);
/// ```
class MapTileCacheService {
  MapTileCacheService._();

  static final MapTileCacheService instance = MapTileCacheService._();

  /// The lowest zoom level for which map tiles are cached.
  static const int minCachedZoom = 5;

  /// The highest zoom level for which map tiles are cached.
  static const int maxCachedZoom = 19;

  Directory? _cacheDir;

  Future<void> _ensureInitialized() async {
    if (_cacheDir != null) return;
    final base = await getApplicationSupportDirectory();
    _cacheDir = Directory(
      '${base.path}${Platform.pathSeparator}map_tiles',
    );
    await _cacheDir!.create(recursive: true);
  }

  /// Extracts `(zoom, x, y)` from a tile [url], or `null` when the URL does
  /// not look like a standard `{zoom}/{x}/{y}` tile URL.
  static TileCoords? parseTileCoords(String url) {
    final segments = Uri.parse(url)
        .pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.length < 3) return null;

    final zoom = int.tryParse(segments[segments.length - 3]);
    final x = int.tryParse(segments[segments.length - 2]);
    final rawY = segments[segments.length - 1];
    final dot = rawY.indexOf('.');
    final y = int.tryParse(dot == -1 ? rawY : rawY.substring(0, dot));
    if (zoom == null || x == null || y == null) return null;

    return (z: zoom, x: x, y: y);
  }

  /// Returns `true` when [zoom] is within the cached zoom range.
  static bool isInCachedZoomRange(int zoom) =>
      zoom >= minCachedZoom && zoom <= maxCachedZoom;

  /// Returns the tile URL with the same shape as [url] but for the given
  /// [z], [x] and [y] coordinates.
  ///
  /// Used to build URLs for prefetching surrounding zoom levels.
  static String urlForCoords(String url, int z, int x, int y) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 3) return url;

    final rawY = segments[segments.length - 1];
    final dot = rawY.indexOf('.');
    final extension = dot == -1 ? '' : rawY.substring(dot);
    final replacement = [
      ...segments.sublist(0, segments.length - 3),
      '$z',
      '$x',
      '$y$extension',
    ];

    return uri.replace(pathSegments: replacement).toString();
  }

  /// Derives a stable file name from a tile [url].
  ///
  /// OSM-style tile URLs end in `{zoom}/{x}/{y}.png`, so the last three path
  /// segments are used when present; any other URL falls back to a hash.
  File _fileFor(String url) {
    final segments = Uri.parse(url)
        .pathSegments
        .where((s) => s.isNotEmpty)
        .toList();

    final String name;
    if (segments.length >= 3) {
      final zoom = segments[segments.length - 3];
      final x = segments[segments.length - 2];
      final y = segments[segments.length - 1];
      name = '${zoom}_${x}_$y';
    } else {
      name = url.hashCode.toRadixString(36);
    }

    return File(
      '${_cacheDir!.path}${Platform.pathSeparator}$name',
    );
  }

  /// Returns the cached bytes for [url], or `null` when not cached.
  ///
  /// Tiles outside the cached zoom range are reported as missing so callers
  /// never render a tile that does not belong to the requested zoom level.
  Future<Uint8List?> readTile(String url) async {
    final coords = parseTileCoords(url);
    if (coords != null && !isInCachedZoomRange(coords.z)) return null;

    try {
      await _ensureInitialized();
      final file = _fileFor(url);
      if (await file.exists()) {
        print('[OfflineMap] Loading cached tile');
        return await file.readAsBytes();
      }
    } catch (e) {
      print('[OfflineMap] Tile cache read failed: $e');
    }
    return null;
  }

  /// Writes [bytes] to the cache for [url], overwriting any previous entry.
  Future<void> writeTile(String url, Uint8List bytes) async {
    final coords = parseTileCoords(url);
    if (coords == null || !isInCachedZoomRange(coords.z)) return;

    try {
      await _ensureInitialized();
      final file = _fileFor(url);
      await file.writeAsBytes(bytes, flush: true);
      print(
        '[OfflineMap] Cached tile ${coords.z}/${coords.x}/${coords.y}',
      );
    } catch (e) {
      print('[OfflineMap] Tile cache write failed: $e');
    }
  }
}
