import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/wilayas.dart';
import '../models/models.dart';
import 'db.dart';
import 'location_service.dart';

/// Everything gathered during the countdown, so sending is instant.
class PreparedAlert {
  final GeoPoint2? point;
  final Wilaya wilaya;
  final WilayaNumbers? numbers;
  final List<EmergencyContact> contacts;
  final AppConfig config;

  const PreparedAlert({
    required this.point,
    required this.wilaya,
    required this.numbers,
    required this.contacts,
    required this.config,
  });
}

class DispatchResult {
  final String? alertId;
  final List<String> smsOk;
  final List<String> smsFailed;
  final String? called;
  final bool testMode;
  final bool missingTestNumber;
  final bool hasLocation;

  const DispatchResult({
    required this.alertId,
    required this.smsOk,
    required this.smsFailed,
    required this.called,
    required this.testMode,
    required this.missingTestNumber,
    required this.hasLocation,
  });
}

/// Sends SMS / places calls and records alerts.
///
/// SAFETY: in test mode, police and civil-protection numbers are replaced by
/// the test number. Test mode is on by default and can also be forced for
/// everyone by the admin (config/app.forceTestMode).
class EmergencyService {
  static const _channel = MethodChannel('solvex/emergency');

  final Db db;
  final LocationService location;

  EmergencyService(this.db, this.location);

  static bool isTestMode(AppUser u, AppConfig c) => c.forceTestMode || u.testMode;

  static String cleanPhoneNumber(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final hasPlus = s.startsWith('+');
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return hasPlus ? '+$digits' : digits;
  }

  static String testNumber(AppUser u, AppConfig c) =>
      cleanPhoneNumber(u.testPhoneNumber).isNotEmpty
          ? cleanPhoneNumber(u.testPhoneNumber)
          : cleanPhoneNumber(c.defaultTestNumber);

  static String resolveCallTarget(AppUser user, List<EmergencyContact> contacts, AppConfig config) {
    final userTest = cleanPhoneNumber(user.testPhoneNumber);
    final userPhone = cleanPhoneNumber(user.phone);

    // 1. If user explicitly configured a test phone number different from user's own login phone
    if (userTest.isNotEmpty && userTest != userPhone) {
      return userTest;
    }
    // 2. If user registered emergency contacts in the contacts tab
    final validContacts = contacts
        .map((c) => cleanPhoneNumber(c.phone))
        .where((p) => p.isNotEmpty)
        .toList();
    if (validContacts.isNotEmpty) {
      return validContacts.first;
    }
    // 3. User's test phone number even if equal to user phone
    if (userTest.isNotEmpty) {
      return userTest;
    }
    // 4. Fallback to default test number in config
    final def = cleanPhoneNumber(config.defaultTestNumber);
    if (def.isNotEmpty) {
      return def;
    }
    return '0555999888';
  }

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ------------------------------------------------------------ permissions
  List<Permission> get _needed => [
        Permission.locationWhenInUse,
        if (_isAndroid) ...[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.sms,
          Permission.phone,
          Permission.notification,
        ] else
          Permission.bluetooth,
      ];

  Future<bool> isLocationGranted() async {
    if (kIsWeb) return true;
    try {
      final s = await Permission.locationWhenInUse.status;
      return s.isGranted || s.isLimited;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isNotificationGranted() async {
    if (kIsWeb) return true;
    try {
      final s = await Permission.notification.status;
      return s.isGranted || s.isLimited;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true;
    try {
      final s = await Permission.locationWhenInUse.request();
      return s.isGranted || s.isLimited;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      final s = await Permission.notification.request();
      return s.isGranted || s.isLimited;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestAllCorePermissions() async {
    if (kIsWeb) return;
    try {
      // 1. Request Location (essential for GPS position, safe routes, and wilaya)
      await Permission.locationWhenInUse.request();
      // 2. Request Notification (essential for real-time crash countdown and warnings)
      await Permission.notification.request();
      // 3. Request remaining communication/connectivity permissions
      if (_isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.sms,
          Permission.phone,
        ].request();
      }
    } catch (_) {}
  }

  Future<bool> hasAllPermissions() async {
    if (kIsWeb) return true;
    try {
      final loc = await isLocationGranted();
      final notif = await isNotificationGranted();
      if (!loc || !notif) return false;
      for (final p in _needed) {
        if (!await p.isGranted) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      await requestAllCorePermissions();
      return await hasAllPermissions();
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------ prepare / send
  Future<PreparedAlert> prepare(AppUser user, AccidentEvent e) async {
    final configF = db.getConfig();
    final contactsF = db.getContacts(user.uid).catchError((_) => <EmergencyContact>[]);

    GeoPoint2? point;
    if (e.gpsFix && e.lat != null && e.lng != null) {
      point = GeoPoint2(e.lat!, e.lng!);
    } else {
      point = await location.current(timeout: const Duration(seconds: 8));
    }

    Wilaya wilaya = Wilayas.byCode(user.wilayaCode) ?? Wilayas.byCode(16)!;
    if (point != null) wilaya = await location.wilayaAt(point.lat, point.lng);

    WilayaNumbers? numbers;
    try {
      numbers = await db.getWilayaNumbers(wilaya.code);
      // Fall back to the user's own wilaya if the detected one has no entry.
      if (numbers == null && wilaya.code != user.wilayaCode) {
        numbers = await db.getWilayaNumbers(user.wilayaCode);
      }
    } catch (_) {}

    return PreparedAlert(
      point: point,
      wilaya: wilaya,
      numbers: numbers,
      contacts: await contactsF,
      config: await configF,
    );
  }

  String buildMessage(AppUser user, PreparedAlert p, {required bool test}) {
    final veh = user.vehicleType == VehicleType.car ? 'Voiture / سيارة' : 'Moto / دراجة نارية';
    final b = StringBuffer();
    if (test) b.writeln('[TEST - Slamtek]');
    b.writeln('Slamtek سلامتك: ACCIDENT détecté / حادث مرور');
    b.writeln('Nom: ${user.fullName}');
    b.writeln('Tel: ${user.phone}');
    b.writeln('Vehicule: $veh');
    b.writeln('Wilaya: ${p.wilaya.label('fr')}');
    if (p.point != null) {
      b.writeln('Position: ${p.point!.mapsLink}');
    } else {
      b.writeln('Position: indisponible / غير متوفر');
    }
    return b.toString().trim();
  }

  Future<DispatchResult> dispatch(AppUser user, AccidentEvent e, PreparedAlert p) async {
    final test = isTestMode(user, p.config);

    // Authorities (replaced by the resolved target number in test mode).
    final authorities = <String>[];
    String? callTarget;

    final contactNumbers = p.contacts
        .map((c) => cleanPhoneNumber(c.phone))
        .where((n) => n.isNotEmpty)
        .toList();

    if (test) {
      callTarget = resolveCallTarget(user, p.contacts, p.config);
      if (callTarget.isNotEmpty) {
        authorities.add(callTarget);
      }
    } else if (p.numbers != null) {
      final pol = cleanPhoneNumber(p.numbers!.police);
      final civ = cleanPhoneNumber(p.numbers!.civilProtection);
      if (pol.isNotEmpty) authorities.add(pol);
      if (civ.isNotEmpty) authorities.add(civ);
      callTarget = civ.isNotEmpty ? civ : (pol.isNotEmpty ? pol : null);
    }
    callTarget ??= contactNumbers.isNotEmpty ? contactNumbers.first : null;

    final targets = _dedupe([...authorities, ...contactNumbers]);
    final text = buildMessage(user, p, test: test);

    final ok = <String>[];
    final failed = <String>[];
    for (final n in targets) {
      if (await sendSms(n, text)) {
        ok.add(n);
      } else {
        failed.add(n);
      }
    }

    String? alertId;
    try {
      alertId = await db.createAlert(
        user: user,
        deviceId: e.deviceId == null ? null : Db.deviceIdFromRemote(e.deviceId!),
        lat: p.point?.lat,
        lng: p.point?.lng,
        wilayaCode: p.wilaya.code,
        vehicleType: user.vehicleType,
        cancelled: false,
        testMode: test,
        trigger: e.trigger,
        peakG: e.peakG,
        tilt: e.tilt,
        notifiedNumbers: ok,
      );
    } catch (_) {}

    String? called;
    if (callTarget != null && callTarget.isNotEmpty) {
      if (await call(callTarget)) {
        called = callTarget;
      }
    }

    return DispatchResult(
      alertId: alertId,
      smsOk: ok,
      smsFailed: failed,
      called: called,
      testMode: test,
      missingTestNumber: test && (callTarget == null || callTarget.isEmpty),
      hasLocation: p.point != null,
    );
  }

  /// Records an alert the user cancelled with "I'm OK".
  Future<void> recordCancelled(AppUser user, AccidentEvent e, PreparedAlert? p) async {
    try {
      await db.createAlert(
        user: user,
        deviceId: e.deviceId == null ? null : Db.deviceIdFromRemote(e.deviceId!),
        lat: p?.point?.lat ?? e.lat,
        lng: p?.point?.lng ?? e.lng,
        wilayaCode: p?.wilaya.code ?? user.wilayaCode,
        vehicleType: user.vehicleType,
        cancelled: true,
        testMode: p == null ? true : isTestMode(user, p.config),
        trigger: e.trigger,
        peakG: e.peakG,
        tilt: e.tilt,
      );
    } catch (_) {}
  }

  // ------------------------------------------------------------ platform
  Future<bool> sendSms(String number, String text) async {
    final clean = cleanPhoneNumber(number);
    if (clean.isEmpty) return false;
    if (_isAndroid) {
      try {
        final status = await Permission.sms.status;
        if (!status.isGranted) {
          await Permission.sms.request();
        }
      } catch (_) {}
      try {
        return await _channel.invokeMethod<bool>('sendSms', {'number': clean, 'text': text}) ??
            false;
      } catch (_) {
        return false;
      }
    }
    // iOS cannot send SMS silently: open the composer instead.
    try {
      return await launchUrl(Uri(scheme: 'sms', path: clean, queryParameters: {'body': text}));
    } catch (_) {
      return false;
    }
  }

  Future<bool> call(String number) async {
    final clean = cleanPhoneNumber(number);
    if (clean.isEmpty) return false;
    if (_isAndroid) {
      try {
        final status = await Permission.phone.status;
        if (!status.isGranted) {
          await Permission.phone.request();
        }
      } catch (_) {}
      try {
        final res = await _channel.invokeMethod<bool>('call', {'number': clean});
        if (res == true) return true;
      } catch (_) {}
    }
    // Reliable fallback: launchUrl with tel scheme in external application mode
    try {
      final uri = Uri(scheme: 'tel', path: clean);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Lets the alarm screen show over the lock screen (Android).
  Future<void> showOverLockScreen(bool on) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('showOverLockScreen', {'on': on});
    } catch (_) {}
  }

  static List<String> _dedupe(Iterable<String> numbers) {
    final seen = <String>{};
    final out = <String>[];
    for (final n in numbers) {
      final t = n.trim();
      final key = t.replaceAll(RegExp(r'[^0-9]'), '');
      if (t.isEmpty || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(t);
    }
    return out;
  }
}
