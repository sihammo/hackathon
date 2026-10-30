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

  static String testNumber(AppUser u, AppConfig c) =>
      u.testPhoneNumber.trim().isNotEmpty ? u.testPhoneNumber.trim() : c.defaultTestNumber.trim();

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

  Future<bool> hasAllPermissions() async {
    if (kIsWeb) return true;
    try {
      for (final p in _needed) {
        if (!await p.isGranted) return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      final res = await _needed.request();
      return res.values.every((s) => s.isGranted || s.isLimited);
    } catch (_) {
      return true;
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
    if (test) b.writeln('[TEST - SolveX]');
    b.writeln('SolveX Alert: ACCIDENT détecté / حادث مرور');
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
    final testNum = testNumber(user, p.config);

    // Authorities (replaced by the test number in test mode).
    final authorities = <String>[];
    String? callTarget;
    if (test) {
      if (testNum.isNotEmpty) {
        authorities.add(testNum);
        callTarget = testNum;
      }
    } else if (p.numbers != null) {
      if (p.numbers!.police.isNotEmpty) authorities.add(p.numbers!.police);
      if (p.numbers!.civilProtection.isNotEmpty) authorities.add(p.numbers!.civilProtection);
      callTarget = p.numbers!.civilProtection.isNotEmpty
          ? p.numbers!.civilProtection
          : (p.numbers!.police.isNotEmpty ? p.numbers!.police : null);
    }
    final contactNumbers = p.contacts.map((c) => c.phone).where((n) => n.trim().isNotEmpty);
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
    if (callTarget != null && await call(callTarget)) called = callTarget;

    return DispatchResult(
      alertId: alertId,
      smsOk: ok,
      smsFailed: failed,
      called: called,
      testMode: test,
      missingTestNumber: test && testNum.isEmpty,
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
    if (_isAndroid) {
      try {
        return await _channel.invokeMethod<bool>('sendSms', {'number': number, 'text': text}) ??
            false;
      } catch (_) {
        return false;
      }
    }
    // iOS cannot send SMS silently: open the composer instead.
    try {
      return await launchUrl(Uri(scheme: 'sms', path: number, queryParameters: {'body': text}));
    } catch (_) {
      return false;
    }
  }

  Future<bool> call(String number) async {
    if (_isAndroid) {
      try {
        return await _channel.invokeMethod<bool>('call', {'number': number}) ?? false;
      } catch (_) {
        return false;
      }
    }
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
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
