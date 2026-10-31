import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/constants.dart';
import '../core/wilayas.dart';
import '../models/models.dart';

/// All Firestore access goes through this class.
class Db {
  final FirebaseFirestore? _fs;

  Db([FirebaseFirestore? fs])
      : _fs = fs ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  FirebaseFirestore get firestore {
    final fs = _fs;
    if (fs == null) {
      throw StateError('Firebase is not initialized. Use MockDb for offline / localhost mode.');
    }
    return fs;
  }

  CollectionReference<Map<String, dynamic>> get users => firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get devices => firestore.collection('devices');
  CollectionReference<Map<String, dynamic>> get alerts => firestore.collection('alerts');
  CollectionReference<Map<String, dynamic>> get contacts => firestore.collection('emergencyContacts');
  CollectionReference<Map<String, dynamic>> get wilayaNumbers => firestore.collection('wilayaNumbers');
  CollectionReference<Map<String, dynamic>> get hotspots => firestore.collection('hotspots');
  DocumentReference<Map<String, dynamic>> get configDoc => firestore.collection('config').doc('app');

  // ---------------------------------------------------------------- users
  DocumentReference<Map<String, dynamic>> userDoc(String uid) => users.doc(uid);

  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String username,
    required String phone,
    required int wilayaCode,
  }) {
    return userDoc(uid).set({
      'fullName': fullName,
      'username': username,
      'phone': phone,
      'wilayaCode': wilayaCode,
      'role': 'user',
      'disabled': false,
      'vehicleType': VehicleType.car.id,
      'testMode': true,
      'testPhoneNumber': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      userDoc(uid).update(data);

  Stream<List<AppUser>> allUsers() => users
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000))));

  Future<void> setUserDisabled(String uid, bool disabled) =>
      userDoc(uid).update({'disabled': disabled});

  Future<AppUser> createUserByAdmin({
    required String fullName,
    required String username,
    required String password,
    required String phone,
    required int wilayaCode,
    required VehicleType vehicleType,
    required String role,
  }) async {
    final uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final user = AppUser(
      uid: uid,
      fullName: fullName.trim(),
      username: username.trim().toLowerCase(),
      phone: phone.trim(),
      wilayaCode: wilayaCode,
      role: role,
      disabled: false,
      createdAt: DateTime.now(),
      vehicleType: vehicleType,
      testMode: true,
      testPhoneNumber: phone.trim(),
    );
    await userDoc(uid).set({
      'fullName': user.fullName,
      'username': user.username,
      'phone': user.phone,
      'wilayaCode': user.wilayaCode,
      'role': user.role,
      'disabled': user.disabled,
      'vehicleType': user.vehicleType.id,
      'testMode': user.testMode,
      'testPhoneNumber': user.testPhoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return user;
  }

  Future<void> deleteUser(String uid) async {
    await userDoc(uid).delete();
  }

  Future<void> clearAllUsers({required String currentAdminUid}) async {
    final snaps = await users.get();
    for (final doc in snaps.docs) {
      if (doc.id != currentAdminUid) {
        await doc.reference.delete();
      }
    }
  }

  // ---------------------------------------------------------------- contacts
  Stream<List<EmergencyContact>> contactsOf(String uid) => contacts
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(EmergencyContact.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  Future<List<EmergencyContact>> getContacts(String uid) async {
    final s = await contacts.where('userId', isEqualTo: uid).get();
    return s.docs.map(EmergencyContact.fromDoc).toList();
  }

  Future<void> addContact(String uid, String name, String phone, String relation) =>
      contacts.add({
        'userId': uid,
        'name': name,
        'phone': phone,
        'relation': relation,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateContact(EmergencyContact c, String name, String phone, String relation) =>
      contacts.doc(c.id).update({
        'userId': c.userId,
        'name': name,
        'phone': phone,
        'relation': relation,
      });

  Future<void> deleteContact(String id) => contacts.doc(id).delete();

  // ---------------------------------------------------------------- wilaya numbers
  Stream<Map<int, WilayaNumbers>> wilayaNumbersMap() => wilayaNumbers.snapshots().map((s) {
        final m = <int, WilayaNumbers>{};
        for (final d in s.docs) {
          final w = WilayaNumbers.fromDoc(d);
          m[w.code] = w;
        }
        return m;
      });

  Stream<WilayaNumbers?> wilayaNumbersOf(int code) => wilayaNumbers
      .doc('$code')
      .snapshots()
      .map((d) => d.exists ? WilayaNumbers.fromDoc(d) : null);

  Future<WilayaNumbers?> getWilayaNumbers(int code) async {
    final d = await wilayaNumbers.doc('$code').get();
    return d.exists ? WilayaNumbers.fromDoc(d) : null;
  }

  Future<void> setWilayaNumbers(int code, String police, String civil) =>
      wilayaNumbers.doc('$code').set({
        'code': code,
        'nameFr': Wilayas.byCode(code)?.nameFr ?? '',
        'nameAr': Wilayas.byCode(code)?.nameAr ?? '',
        'police': police,
        'civilProtection': civil,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Creates entries for every wilaya that has none yet, using the national
  /// numbers (Police 17, Civil Protection 14). The admin should replace them
  /// with each wilaya's direct lines.
  Future<int> seedMissingWilayas({String police = '17', String civil = '14'}) async {
    final existing = await wilayaNumbers.get();
    final have = existing.docs.map((d) => d.id).toSet();
    final batch = firestore.batch();
    var n = 0;
    for (final w in Wilayas.all) {
      if (have.contains('${w.code}')) continue;
      batch.set(wilayaNumbers.doc('${w.code}'), {
        'code': w.code,
        'nameFr': w.nameFr,
        'nameAr': w.nameAr,
        'police': police,
        'civilProtection': civil,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      n++;
    }
    if (n > 0) await batch.commit();
    return n;
  }

  // ---------------------------------------------------------------- config
  Stream<AppConfig> config() => configDoc.snapshots().map(AppConfig.fromDoc);

  Future<AppConfig> getConfig() async {
    try {
      return AppConfig.fromDoc(await configDoc.get());
    } catch (_) {
      return AppConfig.defaults;
    }
  }

  Future<void> setConfig({bool? forceTestMode, String? defaultTestNumber}) =>
      configDoc.set({
        if (forceTestMode != null) 'forceTestMode': forceTestMode,
        if (defaultTestNumber != null) 'defaultTestNumber': defaultTestNumber,
      }, SetOptions(merge: true));

  // ---------------------------------------------------------------- devices
  static String deviceIdFromRemote(String remoteId) =>
      remoteId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<void> upsertDevice({
    required String deviceId,
    required String uid,
    required String name,
    required VehicleType vehicleType,
    required bool connected,
  }) =>
      devices.doc(deviceId).set({
        'userId': uid,
        'name': name,
        'vehicleType': vehicleType.id,
        'connected': connected,
        'lastSeen': FieldValue.serverTimestamp(),
        if (connected) 'registeredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<DeviceInfo>> allDevices() =>
      devices.snapshots().map((s) => s.docs.map(DeviceInfo.fromDoc).toList());

  // ---------------------------------------------------------------- alerts
  /// Saves an alert (and its anonymous hotspot unless cancelled). Returns its id.
  Future<String> createAlert({
    required AppUser user,
    required String? deviceId,
    required double? lat,
    required double? lng,
    required int wilayaCode,
    required VehicleType vehicleType,
    required bool cancelled,
    required bool testMode,
    required String trigger,
    double? peakG,
    double? tilt,
    List<String> notifiedNumbers = const [],
  }) async {
    final now = FieldValue.serverTimestamp();
    final status = cancelled ? AlertStatus.cancelled : AlertStatus.sent;
    final ref = alerts.doc();
    final batch = firestore.batch();
    batch.set(ref, {
      'userId': user.uid,
      'userName': user.fullName,
      'userPhone': user.phone,
      'deviceId': deviceId,
      'createdAt': now,
      'clientTime': Timestamp.now(),
      'lat': lat,
      'lng': lng,
      'wilayaCode': wilayaCode,
      'wilayaName': Wilayas.byCode(wilayaCode)?.nameFr ?? '',
      'vehicleType': vehicleType.id,
      'status': status,
      'statusTimestamps': {status: now},
      'responses': cancelled
          ? {}
          : {
              for (final s in EmergencyServiceType.all)
                s: {
                  'status': AlertStatus.sent,
                  'statusTimestamps': {AlertStatus.sent: now},
                },
            },
      'testMode': testMode,
      'trigger': trigger,
      'peakG': peakG,
      'tilt': tilt,
      'notifiedNumbers': notifiedNumbers,
    });
    if (!cancelled && lat != null && lng != null) {
      batch.set(hotspots.doc(ref.id), {
        'lat': lat,
        'lng': lng,
        'vehicleType': vehicleType.id,
        'wilayaCode': wilayaCode,
        'createdAt': now,
      });
    }
    await batch.commit();
    return ref.id;
  }

  Stream<List<AlertModel>> alertsOf(String uid) => alerts
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => _sorted(s.docs.map(AlertModel.fromDoc).toList()));

  Stream<List<AlertModel>> allAlerts() =>
      alerts.snapshots().map((s) => _sorted(s.docs.map(AlertModel.fromDoc).toList()));

  Stream<AlertModel?> alert(String id) =>
      alerts.doc(id).snapshots().map((d) => d.exists ? AlertModel.fromDoc(d) : null);

  Stream<List<Hotspot>> allHotspots() =>
      hotspots.snapshots().map((s) => s.docs.map(Hotspot.fromDoc).toList());

  /// Moves one service (police / civil) to [newStatus] and recomputes the
  /// alert's overall status (= the most advanced stage of any service).
  Future<void> setServiceStatus(String alertId, String service, String newStatus) {
    final ref = alerts.doc(alertId);
    return firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final a = AlertModel.fromDoc(snap);
      if (a.isCancelled) return;
      final now = Timestamp.now();

      final responses = <String, dynamic>{};
      var maxIdx = 0;
      for (final s in EmergencyServiceType.all) {
        final r = a.response(s);
        final ts = <String, dynamic>{
          for (final e in r.timestamps.entries) e.key: Timestamp.fromDate(e.value),
        };
        var st = r.status;
        if (s == service) {
          st = newStatus;
          // Fill every stage up to the new one so response times stay computable.
          final idx = AlertStatus.indexOf(newStatus);
          for (var i = 0; i <= idx; i++) {
            ts.putIfAbsent(AlertStatus.stages[i], () => now);
          }
        }
        responses[s] = {'status': st, 'statusTimestamps': ts};
        final i = AlertStatus.indexOf(st);
        if (i > maxIdx) maxIdx = i;
      }

      final overall = AlertStatus.stages[maxIdx];
      final overallTs = <String, dynamic>{
        for (final e in a.statusTimestamps.entries) e.key: Timestamp.fromDate(e.value),
      };
      for (var i = 0; i <= maxIdx; i++) {
        overallTs.putIfAbsent(AlertStatus.stages[i], () => now);
      }

      tx.update(ref, {
        'responses': responses,
        'status': overall,
        'statusTimestamps': overallTs,
      });
    });
  }

  static List<AlertModel> _sorted(List<AlertModel> l) => l
    ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
}
