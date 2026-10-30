import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/wilayas.dart';
import '../models/models.dart';
import 'voice_service.dart';

class GeoPoint2 {
  final double lat;
  final double lng;
  const GeoPoint2(this.lat, this.lng);

  String get mapsLink =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
}

/// Manages GPS user positioning, proximity detection to accident black points,
/// and triggers automatic voice warnings.
class LocationService extends ChangeNotifier {
  // Current user position: Place du 1er Mai / Rue Hassiba Ben Bouali (Alger Centre)
  GeoPoint2 _current = const GeoPoint2(36.7510, 3.0555);
  GeoPoint2 get userLocation => _current;

  bool _isNearBlackPoint = false;
  bool get isNearBlackPoint => _isNearBlackPoint;

  Hotspot? _nearestHotspot;
  Hotspot? get nearestHotspot => _nearestHotspot;

  double _distanceMeters = 1500;
  double get distanceMeters => _distanceMeters;

  DateTime? _lastWarningSpokenAt;

  Future<bool> ensurePermission() async {
    if (kIsWeb) return true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Phone GPS position; falls back to the internal current position.
  Future<GeoPoint2?> current({Duration timeout = const Duration(seconds: 10)}) async {
    if (kIsWeb) return _current;
    if (!await ensurePermission()) return _current;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
      _current = GeoPoint2(p.latitude, p.longitude);
      notifyListeners();
      return _current;
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        if (p != null) {
          _current = GeoPoint2(p.latitude, p.longitude);
          notifyListeners();
          return _current;
        }
      } catch (_) {}
      return _current;
    }
  }

  /// Wilaya containing the point: reverse geocoding first, nearest capital otherwise.
  Future<Wilaya> wilayaAt(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 4));
      for (final m in marks) {
        final w = Wilayas.matchName(m.administrativeArea) ??
            Wilayas.matchName(m.subAdministrativeArea);
        if (w != null) return w;
      }
    } catch (_) {}
    return Wilayas.nearest(lat, lng);
  }

  /// Detects the user's current wilaya from the GPS position.
  Future<Wilaya?> detectWilaya() async {
    final p = await current();
    if (p == null) return null;
    return wilayaAt(p.lat, p.lng);
  }

  /// Simulates moving close to an accident black point (< 200m) to test proximity and voice warning.
  void simulateMoveNearBlackPoint(List<Hotspot> hotspots, {bool isArabic = false}) {
    if (hotspots.isEmpty) return;
    final target = hotspots.first;
    // Set user position 180m away from the Algiers black point
    _current = GeoPoint2(target.lat - 0.0012, target.lng - 0.0008);
    checkProximity(hotspots, isArabic: isArabic, forceVoice: true);
    notifyListeners();
  }

  /// Simulates moving back to a safe zone away from accident black points.
  void simulateMoveToSafeZone(List<Hotspot> hotspots) {
    _current = const GeoPoint2(36.7510, 3.0555);
    checkProximity(hotspots);
    notifyListeners();
  }

  /// Updates current position and checks proximity against known black points.
  void setLocation(GeoPoint2 loc, List<Hotspot> hotspots, {bool isArabic = false}) {
    _current = loc;
    checkProximity(hotspots, isArabic: isArabic);
    notifyListeners();
  }

  /// Checks if user is within 500m of any black point and triggers voice alerts.
  void checkProximity(List<Hotspot> hotspots, {bool isArabic = false, bool forceVoice = false}) {
    if (hotspots.isEmpty) {
      _isNearBlackPoint = false;
      _nearestHotspot = null;
      notifyListeners();
      return;
    }

    Hotspot? closest;
    double minDistance = double.infinity;

    for (final h in hotspots) {
      final d = _haversineMeters(_current.lat, _current.lng, h.lat, h.lng);
      if (d < minDistance) {
        minDistance = d;
        closest = h;
      }
    }

    _distanceMeters = minDistance;
    _nearestHotspot = closest;

    // Threshold: within 500 meters of a black point
    final wasNear = _isNearBlackPoint;
    _isNearBlackPoint = minDistance <= 500;

    // Trigger voice warning
    if (_isNearBlackPoint && (!wasNear || forceVoice || _shouldSpeakAgain())) {
      _lastWarningSpokenAt = DateTime.now();
      VoiceService.speakBlackPointWarning(isArabic: isArabic);
    }

    notifyListeners();
  }

  void speakCurrentWarning({bool isArabic = false}) {
    VoiceService.speakBlackPointWarning(isArabic: isArabic);
  }

  bool _shouldSpeakAgain() {
    if (_lastWarningSpokenAt == null) return true;
    return DateTime.now().difference(_lastWarningSpokenAt!) > const Duration(seconds: 40);
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742000 * math.asin(math.sqrt(a)); // 2 * R in meters
  }
}
