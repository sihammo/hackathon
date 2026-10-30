import 'dart:async';

import '../core/constants.dart';
import '../core/wilayas.dart';
import '../models/models.dart';
import 'db.dart';

/// In-memory mock database for local development, web testing, and demonstrations
/// when Firebase is not configured or in offline mode.
class MockDb extends Db {
  static final AppUser demoUser = AppUser(
    uid: 'demo-user-1',
    fullName: 'Karim Benali',
    username: 'karim',
    phone: '0555123456',
    wilayaCode: 16,
    role: 'user',
    disabled: false,
    createdAt: DateTime.now().subtract(const Duration(days: 15)),
    vehicleType: VehicleType.car,
    testMode: true,
    testPhoneNumber: '0555999888',
  );

  static final AppUser demoAdmin = AppUser(
    uid: 'demo-admin-1',
    fullName: 'Directeur Slamtek',
    username: 'admin',
    phone: '0550000000',
    wilayaCode: 16,
    role: 'admin',
    disabled: false,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    vehicleType: VehicleType.car,
    testMode: true,
    testPhoneNumber: '0555999888',
  );

  final Map<String, AppUser> _users = {};
  final List<EmergencyContact> _contacts = [];
  final Map<int, WilayaNumbers> _wilayaNumbers = {};
  AppConfig _config = const AppConfig(forceTestMode: true, defaultTestNumber: '0555999888');
  final List<DeviceInfo> _devices = [];
  final List<AlertModel> _alerts = [];
  final List<Hotspot> _hotspots = [];

  final _usersCtrl = StreamController<List<AppUser>>.broadcast();
  final _contactsCtrl = StreamController<List<EmergencyContact>>.broadcast();
  final _wilayaCtrl = StreamController<Map<int, WilayaNumbers>>.broadcast();
  final _configCtrl = StreamController<AppConfig>.broadcast();
  final _devicesCtrl = StreamController<List<DeviceInfo>>.broadcast();
  final _alertsCtrl = StreamController<List<AlertModel>>.broadcast();
  final _hotspotsCtrl = StreamController<List<Hotspot>>.broadcast();

  MockDb() : super(null) {
    _seedData();
  }

  void _seedData() {
    _users[demoUser.uid] = demoUser;
    _users[demoAdmin.uid] = demoAdmin;

    _contacts.addAll([
      const EmergencyContact(
        id: 'c1',
        userId: 'demo-user-1',
        name: 'Yacine Benali (Frère)',
        phone: '0551223344',
        relation: 'Frère',
      ),
      const EmergencyContact(
        id: 'c2',
        userId: 'demo-user-1',
        name: 'Amina Benali (Mère)',
        phone: '0661998877',
        relation: 'Mère',
      ),
    ]);

    for (final w in Wilayas.all) {
      _wilayaNumbers[w.code] = WilayaNumbers(
        code: w.code,
        police: '17',
        civilProtection: '14',
        updatedAt: DateTime.now(),
      );
    }

    final now = DateTime.now();

    _devices.add(
      DeviceInfo(
        id: 'SOLVEX-A101',
        userId: 'demo-user-1',
        name: 'Slamtek ESP32-Box #101',
        vehicleType: VehicleType.car,
        connected: true,
        lastSeen: now,
        registeredAt: now.subtract(const Duration(days: 15)),
      ),
    );

    final initialBuyers = [
      ('u2', 'Samir Mansour', 'samir', '0770334455', 31, VehicleType.motorcycle, 2),
      ('u3', 'Nadia Khelifi', 'nadia', '0661556677', 9, VehicleType.car, 4),
      ('u4', 'Mohamed Larbi', 'mohamed_l', '0550112233', 25, VehicleType.car, 7),
      ('u5', 'Amina Zerrouki', 'amina_z', '0662334455', 19, VehicleType.car, 10),
      ('u6', 'Yacine Mansouri', 'yacine_m', '0771889900', 31, VehicleType.motorcycle, 12),
      ('u7', 'Dr. Meriem Saidi', 'meriem_s', '0555443322', 25, VehicleType.car, 14),
      ('u8', 'Sofiane Bouzid', 'sofiane_b', '0663778899', 19, VehicleType.car, 16),
      ('u9', 'Bilal Haddad', 'bilal_h', '0772112233', 9, VehicleType.motorcycle, 18),
      ('u10', 'Ryad Belkacem', 'ryad_b', '0551998877', 23, VehicleType.car, 21),
      ('u11', 'Nabil Guellil', 'nabil_g', '0773445566', 13, VehicleType.car, 24),
      ('u12', 'Farida Meftah', 'farida_m', '0664887766', 15, VehicleType.car, 28),
      ('u13', 'Walid Boudiaf', 'walid_b', '0552667788', 5, VehicleType.motorcycle, 32),
      ('u14', 'Khaled Benaissa', 'khaled_b', '0774332211', 2, VehicleType.car, 35),
      ('u15', 'Rym Amrani', 'rym_a', '0665112233', 6, VehicleType.car, 38),
      ('u16', 'Omar Rahmani', 'omar_r', '0553778899', 7, VehicleType.car, 42),
      ('u17', 'Zahra Messaoudi', 'zahra_m', '0775998877', 30, VehicleType.car, 46),
      ('u18', 'Hamza Benyoucef', 'hamza_b', '0666443322', 14, VehicleType.motorcycle, 50),
      ('u19', 'Tariq Slimani', 'tariq_s', '0554112233', 17, VehicleType.car, 55),
      ('u20', 'Amel Touati', 'amel_t', '0776554433', 16, VehicleType.car, 60),
    ];

    for (var i = 0; i < initialBuyers.length; i++) {
      final b = initialBuyers[i];
      final created = now.subtract(Duration(days: b.$7));
      final user = AppUser(
        uid: b.$1,
        fullName: b.$2,
        username: b.$3,
        phone: b.$4,
        wilayaCode: b.$5,
        role: 'user',
        disabled: false,
        createdAt: created,
        vehicleType: b.$6,
        testMode: false,
        testPhoneNumber: b.$4,
      );
      _users[user.uid] = user;

      _devices.add(
        DeviceInfo(
          id: 'SOLVEX-${b.$6 == VehicleType.car ? "A" : "M"}${102 + i}',
          userId: user.uid,
          name: 'Slamtek IoT Box #${102 + i}',
          vehicleType: b.$6,
          connected: i % 4 != 0, // 75% online
          lastSeen: now.subtract(Duration(minutes: (i * 11) % 180)),
          registeredAt: created,
        ),
      );
    }

    _alerts.addAll([
      AlertModel(
        id: 'a1',
        userId: 'demo-user-1',
        userName: 'Karim Benali',
        userPhone: '0555123456',
        deviceId: 'SOLVEX-A1',
        createdAt: now.subtract(const Duration(minutes: 45)),
        lat: 36.7538,
        lng: 3.0588,
        wilayaCode: 16,
        vehicleType: VehicleType.car,
        status: AlertStatus.arrived,
        statusTimestamps: {
          AlertStatus.sent: now.subtract(const Duration(minutes: 45)),
          AlertStatus.received: now.subtract(const Duration(minutes: 42)),
          AlertStatus.dispatched: now.subtract(const Duration(minutes: 38)),
          AlertStatus.arrived: now.subtract(const Duration(minutes: 25)),
        },
        responses: {
          'police': ServiceResponse(AlertStatus.arrived, {
            AlertStatus.sent: now.subtract(const Duration(minutes: 45)),
            AlertStatus.arrived: now.subtract(const Duration(minutes: 25)),
          }),
          'civilProtection': ServiceResponse(AlertStatus.arrived, {
            AlertStatus.sent: now.subtract(const Duration(minutes: 45)),
            AlertStatus.arrived: now.subtract(const Duration(minutes: 28)),
          }),
        },
        testMode: true,
        trigger: 'impact',
        peakG: 4.8,
        tilt: 14.5,
        notifiedNumbers: const ['0551223344', '0661998877'],
      ),
      AlertModel(
        id: 'a2',
        userId: 'u2',
        userName: 'Samir Mansour',
        userPhone: '0770334455',
        deviceId: 'SOLVEX-M1',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        lat: 35.6987,
        lng: -0.6349,
        wilayaCode: 31,
        vehicleType: VehicleType.motorcycle,
        status: AlertStatus.dispatched,
        statusTimestamps: {
          AlertStatus.sent: now.subtract(const Duration(hours: 2, minutes: 15)),
          AlertStatus.received: now.subtract(const Duration(hours: 2, minutes: 10)),
          AlertStatus.dispatched: now.subtract(const Duration(hours: 2, minutes: 2)),
        },
        responses: {
          'police': ServiceResponse(AlertStatus.dispatched, {
            AlertStatus.sent: now.subtract(const Duration(hours: 2, minutes: 15)),
            AlertStatus.dispatched: now.subtract(const Duration(hours: 2, minutes: 2)),
          }),
        },
        testMode: true,
        trigger: 'fall',
        peakG: 3.5,
        tilt: 72.0,
        notifiedNumbers: const ['0770334455'],
      ),
      AlertModel(
        id: 'a3',
        userId: 'u3',
        userName: 'Nadia Khelifi',
        userPhone: '0661556677',
        deviceId: 'SOLVEX-A2',
        createdAt: now.subtract(const Duration(hours: 6)),
        lat: 36.4700,
        lng: 2.8300,
        wilayaCode: 9,
        vehicleType: VehicleType.car,
        status: AlertStatus.resolved,
        statusTimestamps: {
          AlertStatus.sent: now.subtract(const Duration(hours: 6)),
          AlertStatus.received: now.subtract(const Duration(hours: 5, minutes: 55)),
          AlertStatus.dispatched: now.subtract(const Duration(hours: 5, minutes: 45)),
          AlertStatus.arrived: now.subtract(const Duration(hours: 5, minutes: 30)),
          AlertStatus.resolved: now.subtract(const Duration(hours: 4, minutes: 45)),
        },
        responses: {
          'civilProtection': ServiceResponse(AlertStatus.resolved, {
            AlertStatus.sent: now.subtract(const Duration(hours: 6)),
            AlertStatus.resolved: now.subtract(const Duration(hours: 4, minutes: 45)),
          }),
        },
        testMode: true,
        trigger: 'rollover',
        peakG: 5.9,
        tilt: 88.0,
        notifiedNumbers: const [],
      ),
    ]);

    _hotspots.addAll([
      Hotspot('h1', 36.7538, 3.0588, VehicleType.car, now.subtract(const Duration(minutes: 45))),
      Hotspot('h2', 35.6987, -0.6349, VehicleType.motorcycle, now.subtract(const Duration(hours: 2))),
      Hotspot('h3', 36.4700, 2.8300, VehicleType.car, now.subtract(const Duration(hours: 6))),
      Hotspot('h4', 36.3650, 6.6147, VehicleType.car, now.subtract(const Duration(days: 1))),
      Hotspot('h5', 36.9000, 7.7667, VehicleType.motorcycle, now.subtract(const Duration(days: 2))),
    ]);
  }

  AppUser? findUserById(String uid) => _users[uid];

  AppUser? findUserByUsername(String username) {
    final u = username.trim().toLowerCase();
    for (final user in _users.values) {
      if (user.username.toLowerCase() == u) return user;
    }
    return null;
  }

  void addUser(AppUser user) {
    _users[user.uid] = user;
    _usersCtrl.add(_users.values.toList());
  }

  // ---------------------------------------------------------------- users
  @override
  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String username,
    required String phone,
    required int wilayaCode,
  }) async {
    final u = AppUser(
      uid: uid,
      fullName: fullName,
      username: username,
      phone: phone,
      wilayaCode: wilayaCode,
      role: 'user',
      disabled: false,
      createdAt: DateTime.now(),
      vehicleType: VehicleType.car,
      testMode: true,
      testPhoneNumber: '',
    );
    _users[uid] = u;
    _usersCtrl.add(_users.values.toList());
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final existing = _users[uid];
    if (existing == null) return;
    final updated = AppUser(
      uid: existing.uid,
      fullName: (data['fullName'] as String?) ?? existing.fullName,
      username: (data['username'] as String?) ?? existing.username,
      phone: (data['phone'] as String?) ?? existing.phone,
      wilayaCode: (data['wilayaCode'] as int?) ?? existing.wilayaCode,
      role: (data['role'] as String?) ?? existing.role,
      disabled: (data['disabled'] as bool?) ?? existing.disabled,
      createdAt: existing.createdAt,
      vehicleType: data.containsKey('vehicleType')
          ? VehicleType.fromId(data['vehicleType'] as String?)
          : existing.vehicleType,
      testMode: (data['testMode'] as bool?) ?? existing.testMode,
      testPhoneNumber: (data['testPhoneNumber'] as String?) ?? existing.testPhoneNumber,
      avatarUrl: data.containsKey('avatarUrl') ? (data['avatarUrl'] as String?) : existing.avatarUrl,
    );
    _users[uid] = updated;
    _usersCtrl.add(_users.values.toList());
  }

  @override
  Stream<List<AppUser>> allUsers() async* {
    yield _users.values.toList();
    yield* _usersCtrl.stream;
  }

  @override
  Future<void> setUserDisabled(String uid, bool disabled) async {
    await updateUser(uid, {'disabled': disabled});
  }

  // ---------------------------------------------------------------- contacts
  @override
  Stream<List<EmergencyContact>> contactsOf(String uid) async* {
    yield _contacts.where((c) => c.userId == uid).toList();
    yield* _contactsCtrl.stream.map((l) => l.where((c) => c.userId == uid).toList());
  }

  @override
  Future<List<EmergencyContact>> getContacts(String uid) async {
    return _contacts.where((c) => c.userId == uid).toList();
  }

  @override
  Future<void> addContact(String uid, String name, String phone, String relation) async {
    _contacts.add(
      EmergencyContact(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        userId: uid,
        name: name,
        phone: phone,
        relation: relation,
      ),
    );
    _contactsCtrl.add(List.from(_contacts));
  }

  @override
  Future<void> updateContact(EmergencyContact c, String name, String phone, String relation) async {
    final idx = _contacts.indexWhere((e) => e.id == c.id);
    if (idx != -1) {
      _contacts[idx] = EmergencyContact(
        id: c.id,
        userId: c.userId,
        name: name,
        phone: phone,
        relation: relation,
      );
      _contactsCtrl.add(List.from(_contacts));
    }
  }

  @override
  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    _contactsCtrl.add(List.from(_contacts));
  }

  // ---------------------------------------------------------------- wilayas
  @override
  Stream<Map<int, WilayaNumbers>> wilayaNumbersMap() async* {
    yield Map.from(_wilayaNumbers);
    yield* _wilayaCtrl.stream;
  }

  @override
  Stream<WilayaNumbers?> wilayaNumbersOf(int code) async* {
    yield _wilayaNumbers[code];
    yield* _wilayaCtrl.stream.map((m) => m[code]);
  }

  @override
  Future<WilayaNumbers?> getWilayaNumbers(int code) async {
    return _wilayaNumbers[code];
  }

  @override
  Future<void> setWilayaNumbers(int code, String police, String civil) async {
    _wilayaNumbers[code] = WilayaNumbers(
      code: code,
      police: police,
      civilProtection: civil,
      updatedAt: DateTime.now(),
    );
    _wilayaCtrl.add(Map.from(_wilayaNumbers));
  }

  @override
  Future<int> seedMissingWilayas({String police = '17', String civil = '14'}) async {
    var added = 0;
    for (final w in Wilayas.all) {
      if (!_wilayaNumbers.containsKey(w.code)) {
        _wilayaNumbers[w.code] = WilayaNumbers(
          code: w.code,
          police: police,
          civilProtection: civil,
          updatedAt: DateTime.now(),
        );
        added++;
      }
    }
    if (added > 0) _wilayaCtrl.add(Map.from(_wilayaNumbers));
    return added;
  }

  // ---------------------------------------------------------------- config
  @override
  Stream<AppConfig> config() async* {
    yield _config;
    yield* _configCtrl.stream;
  }

  @override
  Future<AppConfig> getConfig() async => _config;

  @override
  Future<void> setConfig({bool? forceTestMode, String? defaultTestNumber}) async {
    _config = AppConfig(
      forceTestMode: forceTestMode ?? _config.forceTestMode,
      defaultTestNumber: defaultTestNumber ?? _config.defaultTestNumber,
    );
    _configCtrl.add(_config);
  }

  // ---------------------------------------------------------------- devices
  @override
  Future<void> upsertDevice({
    required String deviceId,
    required String uid,
    required String name,
    required VehicleType vehicleType,
    required bool connected,
  }) async {
    final idx = _devices.indexWhere((d) => d.id == deviceId);
    final dev = DeviceInfo(
      id: deviceId,
      userId: uid,
      name: name,
      vehicleType: vehicleType,
      connected: connected,
      lastSeen: DateTime.now(),
      registeredAt: idx != -1 ? _devices[idx].registeredAt : DateTime.now(),
    );
    if (idx != -1) {
      _devices[idx] = dev;
    } else {
      _devices.add(dev);
    }
    _devicesCtrl.add(List.from(_devices));
  }

  @override
  Stream<List<DeviceInfo>> allDevices() async* {
    yield List.from(_devices);
    yield* _devicesCtrl.stream;
  }

  // ---------------------------------------------------------------- alerts
  @override
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
    final id = 'alert_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final status = cancelled ? AlertStatus.cancelled : AlertStatus.sent;

    final alert = AlertModel(
      id: id,
      userId: user.uid,
      userName: user.fullName,
      userPhone: user.phone,
      deviceId: deviceId,
      createdAt: now,
      lat: lat,
      lng: lng,
      wilayaCode: wilayaCode,
      vehicleType: vehicleType,
      status: status,
      statusTimestamps: {status: now},
      responses: cancelled
          ? const {}
          : {
              for (final s in EmergencyServiceType.all)
                s: ServiceResponse(AlertStatus.sent, {AlertStatus.sent: now}),
            },
      testMode: testMode,
      trigger: trigger,
      peakG: peakG,
      tilt: tilt,
      notifiedNumbers: notifiedNumbers,
    );

    _alerts.insert(0, alert);
    _alertsCtrl.add(List.from(_alerts));

    if (!cancelled && lat != null && lng != null) {
      _hotspots.insert(0, Hotspot(id, lat, lng, vehicleType, now));
      _hotspotsCtrl.add(List.from(_hotspots));
    }

    return id;
  }

  @override
  Stream<List<AlertModel>> alertsOf(String uid) async* {
    yield _alerts.where((a) => a.userId == uid).toList();
    yield* _alertsCtrl.stream.map((l) => l.where((a) => a.userId == uid).toList());
  }

  @override
  Stream<List<AlertModel>> allAlerts() async* {
    yield List.from(_alerts);
    yield* _alertsCtrl.stream;
  }

  @override
  Stream<AlertModel?> alert(String id) async* {
    yield _alerts.where((a) => a.id == id).firstOrNull;
    yield* _alertsCtrl.stream.map((l) => l.where((a) => a.id == id).firstOrNull);
  }

  @override
  Stream<List<Hotspot>> allHotspots() async* {
    yield List.from(_hotspots);
    yield* _hotspotsCtrl.stream;
  }

  @override
  Future<void> setServiceStatus(String alertId, String service, String newStatus) async {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx == -1) return;
    final a = _alerts[idx];
    if (a.isCancelled) return;
    final now = DateTime.now();

    final resp = Map<String, ServiceResponse>.from(a.responses);
    final curR = a.response(service);
    final curTs = Map<String, DateTime>.from(curR.timestamps);
    curTs[newStatus] = now;
    resp[service] = ServiceResponse(newStatus, curTs);

    final statusTs = Map<String, DateTime>.from(a.statusTimestamps);
    statusTs[newStatus] = now;

    _alerts[idx] = AlertModel(
      id: a.id,
      userId: a.userId,
      userName: a.userName,
      userPhone: a.userPhone,
      deviceId: a.deviceId,
      createdAt: a.createdAt,
      lat: a.lat,
      lng: a.lng,
      wilayaCode: a.wilayaCode,
      vehicleType: a.vehicleType,
      status: newStatus,
      statusTimestamps: statusTs,
      responses: resp,
      testMode: a.testMode,
      trigger: a.trigger,
      peakG: a.peakG,
      tilt: a.tilt,
      notifiedNumbers: a.notifiedNumbers,
    );

    _alertsCtrl.add(List.from(_alerts));
  }
}
