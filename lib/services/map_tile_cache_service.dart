import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// On-disk cache for map tile images, keyed by tile URL.
///
/// Tiles fetched while online are written to the app support directory so
/// they can be served again later when there is no internet connection. The
/// cache is best-effort: every failure is logged and swallowed so that tile
/// rendering never breaks.
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

  Directory? _cacheDir;

  Future<void> _ensureInitialized() async {
    if (_cacheDir != null) return;
    final base = await getApplicationSupportDirectory();
    _cacheDir = Directory(
      '${base.path}${Platform.pathSeparator}map_tiles',
    );
    await _cacheDir!.create(recursive: true);
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
  Future<Uint8List?> readTile(String url) async {
    try {
      await _ensureInitialized();
      final file = _fileFor(url);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      print('[OfflineMap] Tile cache read failed: $e');
    }
    return null;
  }

  /// Writes [bytes] to the cache for [url], overwriting any previous entry.
  Future<void> writeTile(String url, Uint8List bytes) async {
    try {
      await _ensureInitialized();
      final file = _fileFor(url);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      print('[OfflineMap] Tile cache write failed: $e');
    }
  }
}
