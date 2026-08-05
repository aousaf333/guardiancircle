import 'dart:async';
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
/// [MapTileCacheService]: cached tiles are always preferred, and when there is
/// no cached tile while [offline] a transparent tile is returned so the map
/// never renders a broken image.
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
      );

  @override
  Future<void> dispose() async {
    _httpClient.close();
    super.dispose();
  }
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

  const OfflineAwareTileImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.headers,
    required this.offline,
    required this.cache,
    required this.httpClient,
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
      if (offline) {
        print('[OfflineMap] Loading cached tiles');
      }
      return ImmutableBuffer.fromUint8List(cached).then(decode);
    }

    if (offline) {
      // No cached tile while offline: render a transparent tile instead of
      // attempting a doomed network request.
      return ImmutableBuffer.fromUint8List(TileProvider.transparentImage)
          .then(decode);
    }

    try {
      final response = await httpClient.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        await cache.writeTile(url, response.bodyBytes);
        print('[OfflineMap] Cache updated');
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
  int get hashCode => Object.hashAll([url, if (fallbackUrl != null) fallbackUrl, offline]);
}
