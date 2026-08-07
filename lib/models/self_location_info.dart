import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// The user's real current location plus its reverse-geocoded placemark.
///
/// A [SelfLocationInfo] is only ever built from real GPS data or the last
/// cached real location; it is never populated with demo data.
class SelfLocationInfo {
  final Position position;
  final Placemark? placemark;

  /// Whether the position came from the local cache (offline fallback)
  /// instead of a fresh GPS fix.
  final bool fromCache;

  const SelfLocationInfo({
    required this.position,
    this.placemark,
    this.fromCache = false,
  });

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? get _street =>
      _clean(placemark?.street) ?? _clean(placemark?.thoroughfare);
  String? get _neighborhood => _clean(placemark?.subLocality);
  String? get _city => _clean(placemark?.locality);
  String? get _region =>
      _clean(placemark?.administrativeArea) ??
      _clean(placemark?.subAdministrativeArea);
  String? get _country => _clean(placemark?.country);

  /// A short area label (neighbourhood or city) for the location pill.
  ///
  /// Falls back to the raw coordinates when no placemark was resolved.
  String get area => _neighborhood ?? _city ?? _region ?? coordinates;

  /// A full reverse-geocoded address.
  ///
  /// Falls back to the raw coordinates when no placemark was resolved.
  String get address {
    final parts = <String?>[_street, _city, _region, _country]
        .whereType<String>()
        .toList();
    return parts.isEmpty ? coordinates : parts.join(', ');
  }

  /// Human-readable coordinates with cardinal direction.
  String get coordinates {
    final lat = position.latitude;
    final lng = position.longitude;
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}\u00b0 $latDir, '
        '${lng.abs().toStringAsFixed(4)}\u00b0 $lngDir';
  }

  /// GPS horizontal accuracy, e.g. "±10m", or "Unknown" when not reported.
  String get accuracyLabel {
    final accuracy = position.accuracy;
    if (accuracy <= 0) return 'Unknown';
    return '\u00b1${accuracy.round()}m';
  }
}
