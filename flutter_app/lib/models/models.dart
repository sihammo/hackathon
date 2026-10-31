import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

DateTime? tsToDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

Map<String, DateTime> _tsMap(dynamic v) {
  final out = <String, DateTime>{};
  if (v is Map) {
    v.forEach((k, val) {
      final d = tsToDate(val);
      if (d != null) out[k.toString()] = d;
    });
  }
  return out;
}

double? _toDouble(dynamic v) => v is num ? v.toDouble() : null;

// ---------------------------------------------------------------------------
// users/{uid}
// ---------------------------------------------------------------------------
class AppUser {
  final String uid;
  final String fullName;
  final String username;
  final String phone;
  final int wilayaCode;
  final String role; // 'user' | 'admin'
  final bool disabled;
  final DateTime? createdAt;
  final VehicleType vehicleType;
  final bool testMode;
  final String testPhoneNumber;
  final String? avatarUrl;

  const AppUser({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.wilayaCode,
    required this.role,
    required this.disabled,
    required this.createdAt,
    required this.vehicleType,
    required this.testMode,
    required this.testPhoneNumber,
    this.avatarUrl,
  });

  bool get isAdmin => role == 'admin';

  String get effectiveAvatar => (avatarUrl != null && avatarUrl!.isNotEmpty)
      ? avatarUrl!
      : 'assets/images/karim.jpg';

  AppUser copyWith({
    String? fullName,
    String? phone,
    int? wilayaCode,
    VehicleType? vehicleType,
    bool? testMode,
    String? testPhoneNumber,
    String? avatarUrl,
  }) {
    return AppUser(
      uid: uid,
      fullName: fullName ?? this.fullName,
      username: username,
      phone: phone ?? this.phone,
      wilayaCode: wilayaCode ?? this.wilayaCode,
      role: role,
      disabled: disabled,
      createdAt: createdAt,
      vehicleType: vehicleType ?? this.vehicleType,
      testMode: testMode ?? this.testMode,
      testPhoneNumber: testPhoneNumber ?? this.testPhoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      fullName: (d['fullName'] ?? '') as String,
      username: (d['username'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      wilayaCode: (d['wilayaCode'] as num?)?.toInt() ?? 16,
      role: (d['role'] ?? 'user') as String,
      disabled: d['disabled'] == true,
      createdAt: tsToDate(d['createdAt']),
      vehicleType: VehicleType.fromId(d['vehicleType'] as String?),
      // Test mode is ON unless explicitly turned off.
      testMode: d['testMode'] != false,
      testPhoneNumber: (d['testPhoneNumber'] ?? '') as String,
      avatarUrl: d['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'username': username,
        'phone': phone,
        'wilayaCode': wilayaCode,
        'role': role,
        'disabled': disabled,
        'createdAt': createdAt?.toIso8601String(),
        'vehicleType': vehicleType.id,
        'testMode': testMode,
        'testPhoneNumber': testPhoneNumber,
        'avatarUrl': avatarUrl,
      };

  factory AppUser.fromMap(Map<String, dynamic> d) {
    return AppUser(
      uid: (d['uid'] ?? '') as String,
      fullName: (d['fullName'] ?? '') as String,
      username: (d['username'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      wilayaCode: (d['wilayaCode'] as num?)?.toInt() ?? 16,
      role: (d['role'] ?? 'user') as String,
      disabled: d['disabled'] == true,
      createdAt: d['createdAt'] != null ? DateTime.tryParse(d['createdAt'].toString()) : null,
      vehicleType: VehicleType.fromId(d['vehicleType'] as String?),
      testMode: d['testMode'] != false,
      testPhoneNumber: (d['testPhoneNumber'] ?? '') as String,
      avatarUrl: d['avatarUrl'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// alerts/{id}
// ---------------------------------------------------------------------------
class ServiceResponse {
  final String status;
  final Map<String, DateTime> timestamps;

  const ServiceResponse(this.status, this.timestamps);

  factory ServiceResponse.fromMap(dynamic m) {
    if (m is! Map) return const ServiceResponse(AlertStatus.sent, {});
    return ServiceResponse(
      (m['status'] ?? AlertStatus.sent) as String,
      _tsMap(m['statusTimestamps']),
    );
  }

  /// Time between the alert and the team's arrival.
  Duration? responseTime(DateTime? alertTime) {
    final arrived = timestamps[AlertStatus.arrived];
    if (arrived == null || alertTime == null) return null;
    return arrived.difference(alertTime);
  }
}

class AlertModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String? deviceId;
  final DateTime? createdAt;
  final double? lat;
  final double? lng;
  final int wilayaCode;
  final VehicleType vehicleType;
  final String status;
  final Map<String, DateTime> statusTimestamps;
  final Map<String, ServiceResponse> responses;
  final bool testMode;
  final String trigger; // impact | fall | rollover | test | simulation
  final double? peakG;
  final double? tilt;
  final List<String> notifiedNumbers;

  const AlertModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.deviceId,
    required this.createdAt,
    required this.lat,
    required this.lng,
    required this.wilayaCode,
    required this.vehicleType,
    required this.status,
    required this.statusTimestamps,
    required this.responses,
    required this.testMode,
    required this.trigger,
    required this.peakG,
    required this.tilt,
    required this.notifiedNumbers,
  });

  bool get hasLocation => lat != null && lng != null;
  bool get isCancelled => status == AlertStatus.cancelled;

  ServiceResponse response(String service) =>
      responses[service] ?? const ServiceResponse(AlertStatus.sent, {});

  /// First arrival among police / civil protection.
  Duration? get responseTime {
    Duration? best;
    for (final s in EmergencyServiceType.all) {
      final r = responses[s]?.responseTime(createdAt);
      if (r != null && (best == null || r < best)) best = r;
    }
    return best;
  }

  factory AlertModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final resp = <String, ServiceResponse>{};
    final r = d['responses'];
    if (r is Map) {
      r.forEach((k, v) => resp[k.toString()] = ServiceResponse.fromMap(v));
    }
    return AlertModel(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      userName: (d['userName'] ?? '') as String,
      userPhone: (d['userPhone'] ?? '') as String,
      deviceId: d['deviceId'] as String?,
      createdAt: tsToDate(d['createdAt']) ?? tsToDate(d['clientTime']),
      lat: _toDouble(d['lat']),
      lng: _toDouble(d['lng']),
      wilayaCode: (d['wilayaCode'] as num?)?.toInt() ?? 0,
      vehicleType: VehicleType.fromId(d['vehicleType'] as String?),
      status: (d['status'] ?? AlertStatus.sent) as String,
      statusTimestamps: _tsMap(d['statusTimestamps']),
      responses: resp,
      testMode: d['testMode'] == true,
      trigger: (d['trigger'] ?? 'impact') as String,
      peakG: _toDouble(d['peakG']),
      tilt: _toDouble(d['tilt']),
      notifiedNumbers: ((d['notifiedNumbers'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// emergencyContacts/{id}
// ---------------------------------------------------------------------------
class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return EmergencyContact(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      relation: (d['relation'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'phone': phone,
        'relation': relation,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> d) {
    return EmergencyContact(
      id: (d['id'] ?? '') as String,
      userId: (d['userId'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      relation: (d['relation'] ?? '') as String,
    );
  }
}

// ---------------------------------------------------------------------------
// wilayaNumbers/{code}
// ---------------------------------------------------------------------------
class WilayaNumbers {
  final int code;
  final String police;
  final String civilProtection;
  final DateTime? updatedAt;

  const WilayaNumbers({
    required this.code,
    required this.police,
    required this.civilProtection,
    this.updatedAt,
  });

  factory WilayaNumbers.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return WilayaNumbers(
      code: (d['code'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0,
      police: (d['police'] ?? '') as String,
      civilProtection: (d['civilProtection'] ?? '') as String,
      updatedAt: tsToDate(d['updatedAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// devices/{deviceId}
// ---------------------------------------------------------------------------
class DeviceInfo {
  final String id;
  final String userId;
  final String name;
  final VehicleType vehicleType;
  final bool connected;
  final DateTime? lastSeen;
  final DateTime? registeredAt;

  const DeviceInfo({
    required this.id,
    required this.userId,
    required this.name,
    required this.vehicleType,
    required this.connected,
    required this.lastSeen,
    required this.registeredAt,
  });

  /// Considered online if flagged connected and seen in the last 10 minutes.
  bool get isOnline =>
      connected &&
      lastSeen != null &&
      DateTime.now().difference(lastSeen!) < const Duration(minutes: 10);

  factory DeviceInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return DeviceInfo(
      id: doc.id,
      userId: (d['userId'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      vehicleType: VehicleType.fromId(d['vehicleType'] as String?),
      connected: d['connected'] == true,
      lastSeen: tsToDate(d['lastSeen']),
      registeredAt: tsToDate(d['registeredAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// hotspots/{alertId} — anonymous accident points visible to every user.
// ---------------------------------------------------------------------------
class Hotspot {
  final String id;
  final double lat;
  final double lng;
  final VehicleType vehicleType;
  final DateTime? createdAt;

  const Hotspot(this.id, this.lat, this.lng, this.vehicleType, this.createdAt);

  factory Hotspot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Hotspot(
      doc.id,
      _toDouble(d['lat']) ?? 0,
      _toDouble(d['lng']) ?? 0,
      VehicleType.fromId(d['vehicleType'] as String?),
      tsToDate(d['createdAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// config/app — global settings controlled by the admin.
// ---------------------------------------------------------------------------
class AppConfig {
  /// When true, every user is in test mode regardless of their own setting.
  final bool forceTestMode;

  /// Fallback test number when a user has not set their own.
  final String defaultTestNumber;

  const AppConfig({required this.forceTestMode, required this.defaultTestNumber});

  static const defaults = AppConfig(forceTestMode: true, defaultTestNumber: '');

  factory AppConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return defaults;
    final d = doc.data() ?? const {};
    return AppConfig(
      forceTestMode: d['forceTestMode'] != false,
      defaultTestNumber: (d['defaultTestNumber'] ?? '') as String,
    );
  }
}

/// Accident event received from the device (or simulated).
class AccidentEvent {
  final String trigger; // impact | fall | rollover | test | simulation
  final double? lat;
  final double? lng;
  final bool gpsFix;
  final double? peakG;
  final double? tilt;
  final String? deviceId;
  final DateTime receivedAt;

  AccidentEvent({
    required this.trigger,
    this.lat,
    this.lng,
    this.gpsFix = false,
    this.peakG,
    this.tilt,
    this.deviceId,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}
