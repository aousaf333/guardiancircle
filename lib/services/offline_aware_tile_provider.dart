import 'dart:async';
import 'dart:convert' show base64Decode;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';

import 'package:guardiancircle/services/map_tile_cache_service.dart';

/// A [TileProvider] that serves map tiles from the on-disk cache while
/// offline and caches every successfully fetched tile while online.
///
/// This mirrors [NetworkTileProvider] but routes all tile bytes through
/// [MapTileCacheService]: cached tiles are always preferred, and while online
/// the surrounding zoom levels are prefetched in the background. While
/// offline a tile is only displayed when it was cached for exactly the
/// requested zoom level; otherwise the missing-tile placeholder is shown so a
/// lower-resolution tile is never upscaled and stretched.
class OfflineAwareTileProvider extends TileProvider {
  /// Whether the device is currently offline.
  ///
  /// Mutable so a single provider instance can be reused and simply toggled
  /// when connectivity changes, without leaking HTTP clients.
  bool offline;

  /// The tile cache to read from and write to.
  final MapTileCacheService cache;

  /// Long living client used to make all tile requests.
  final BaseClient _httpClient;

  /// Tile URLs that have already been fetched (directly or as a background
  /// prefetch) during this session, used to keep prefetching bounded.
  final Set<String> _knownTiles = <String>{};

  OfflineAwareTileProvider({
    super.headers,
    required this.offline,
    required this.cache,
    BaseClient? httpClient,
  }) : _httpClient = httpClient ?? RetryClient(Client());

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      OfflineAwareTileImageProvider(
        url: getTileUrl(coordinates, options),
        fallbackUrl: getTileFallbackUrl(coordinates, options),
        headers: headers,
        offline: offline,
        cache: cache,
        httpClient: _httpClient,
        provider: this,
      );

  /// Records that [url] was just stored in the cache and, while online,
  /// prefetches the surrounding zoom levels so higher- and lower-resolution
  /// tiles are already available when the connection drops.
  void onTileCached(String url) {
    if (offline) return;
    if (!_knownTiles.add(url)) return;

    final coords = MapTileCacheService.parseTileCoords(url);
    if (coords == null) return;
    final z = coords.z;
    final x = coords.x;
    final y = coords.y;

    // Lower-zoom ancestors, so zooming out offline stays sharp.
    for (var dz = 1; z - dz >= MapTileCacheService.minCachedZoom; dz++) {
      _prefetch(MapTileCacheService.urlForCoords(url, z - dz, x >> dz, y >> dz));
    }

    // The four higher-zoom children, so zooming in one level offline uses
    // real tiles instead of upscaled parents.
    if (z < MapTileCacheService.maxCachedZoom) {
      final x2 = x << 1;
      final y2 = y << 1;
      for (final (i, j) in const [(0, 0), (0, 1), (1, 0), (1, 1)]) {
        _prefetch(
          MapTileCacheService.urlForCoords(url, z + 1, x2 + i, y2 + j),
        );
      }
    }
  }

  /// Fetches [url] in the background and stores it in the cache. Best-effort:
  /// failures are logged and swallowed so tile rendering is never affected.
  Future<void> _prefetch(String url) async {
    if (offline || !_knownTiles.add(url)) return;

    try {
      final response = await _httpClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        await cache.writeTile(url, response.bodyBytes);
      }
    } catch (e) {
      print('[OfflineMap] Tile prefetch error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _httpClient.close();
    super.dispose();
  }
}

/// The image shown when a tile is not available, such as a tile that was
/// never cached before going offline.
///
/// A plain grey "missing tile" image decoded from an embedded PNG so no asset
/// file or network access is required.
final class MissingTilePlaceholder {
  MissingTilePlaceholder._();

  static const String _pngBase64 =
      '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';

  /// The encoded bytes of the missing-tile placeholder image.
  static final Uint8List imageBytes = base64Decode(_pngBase64);
}

/// Dedicated [ImageProvider] for tiles that consults the disk cache before
/// hitting the network.
///
/// The [offline] flag participates in equality so that switching between
/// online and offline produces a different image cache key; combined with
/// `TileLayer.reset` this forces flutter_map to reload tiles from the correct
/// source.
@immutable
class OfflineAwareTileImageProvider
    extends ImageProvider<OfflineAwareTileImageProvider> {
  /// The URL to fetch the tile from (GET request).
  final String url;

  /// Secondary URL used when the primary fetch fails. When non-null the
  /// provider is not cached in memory.
  final String? fallbackUrl;

  /// The headers to include with the tile fetch request.
  final Map<String, String> headers;

  /// Whether the device is currently offline.
  final bool offline;

  /// The tile cache to read from and write to.
  final MapTileCacheService cache;

  /// The HTTP client to use to make network requests.
  final BaseClient httpClient;

  /// The owning provider, used to trigger background prefetches after a tile
  /// is cached.
  final OfflineAwareTileProvider provider;

  const OfflineAwareTileImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.headers,
    required this.offline,
    required this.cache,
    required this.httpClient,
    required this.provider,
  });

  @override
  ImageStreamCompleter loadImage(
    OfflineAwareTileImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: 1,
        debugLabel: url,
        informationCollector: () => [
          DiagnosticsProperty('URL', url),
          DiagnosticsProperty('Fallback URL', fallbackUrl),
          DiagnosticsProperty('Offline', offline),
        ],
      );

  Future<Codec> _load(
    OfflineAwareTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final cached = await cache.readTile(url);
    if (cached != null) {
      // The tile exists for exactly the requested zoom level, so it is served
      // at its native resolution without any upscaling.
      print('[OfflineMap] Using high-resolution cached tile');
      return ImmutableBuffer.fromUint8List(cached).then(decode);
    }

    if (offline) {
      // No tile was cached for this exact zoom level. Render the missing-tile
      // placeholder instead of attempting a doomed network request or
      // upscaling a lower-resolution tile.
      print('[OfflineMap] Missing cached tile');
      return ImmutableBuffer.fromUint8List(MissingTilePlaceholder.imageBytes)
          .then(decode);
    }

    try {
      final response = await httpClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        await cache.writeTile(url, response.bodyBytes);
        provider.onTileCached(url);
        return ImmutableBuffer.fromUint8List(response.bodyBytes).then(decode);
      }
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      print('[OfflineMap] Tile fetch failed: HTTP ${response.statusCode}');
      return ImmutableBuffer.fromUint8List(TileProvider.transparentImage)
          .then(decode);
    } catch (e) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      print('[OfflineMap] Tile fetch error: $e');
      return ImmutableBuffer.fromUint8List(TileProvider.transparentImage)
          .then(decode);
    }
  }

  @override
  SynchronousFuture<OfflineAwareTileImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineAwareTileImageProvider &&
          fallbackUrl == null &&
          url == other.url &&
          offline == other.offline);

  @override
  int get hashCode =>
      Object.hashAll([url, if (fallbackUrl != null) fallbackUrl, offline]);
}
