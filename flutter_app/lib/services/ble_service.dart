import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/models.dart';

enum DeviceLink { disconnected, connecting, connected }

/// Latest status frame from the device.
class DeviceStatus {
  final bool gpsFix;
  final double? lat;
  final double? lng;
  final int? satellites;
  final VehicleType? vehicleType;
  final DateTime at;

  DeviceStatus({
    required this.gpsFix,
    this.lat,
    this.lng,
    this.satellites,
    this.vehicleType,
    DateTime? at,
  }) : at = at ?? DateTime.now();
}

/// Talks to the SolveX ESP32 over Bluetooth Low Energy.
///
/// Protocol (see docs/BLE_PROTOCOL.md):
///  * ALERT  (notify)  {"t":"acc","id":3,"type":"impact","g":5.1,"tilt":12,"fix":1,"lat":..,"lng":..}
///  * STATUS (notify)  {"t":"st","veh":"car","fix":1,"lat":..,"lng":..,"sat":7}
///  * CONFIG (write)   {"veh":"car"|"moto"} | {"cmd":"ack","id":3} | {"cmd":"test"} | {"cmd":"cal"}
class BleService extends ChangeNotifier {
  static const _prefKey = 'paired_device_id';
  static const _prefName = 'paired_device_name';

  final SharedPreferences _prefs;

  BleService(this._prefs);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _configChar;
  StreamSubscription? _connSub;
  final List<StreamSubscription> _charSubs = [];
  Timer? _reconnectTimer;
  bool _userDisconnect = false;
  final Set<int> _seenAlertIds = {};

  DeviceLink link = DeviceLink.disconnected;
  DeviceStatus? status;
  String? lastError;

  /// Called when the link goes up or down (used to update Firestore).
  void Function(String remoteId, String name, bool connected)? onLinkChanged;

  /// Vehicle type to push to the device as soon as it connects.
  VehicleType vehicleType = VehicleType.car;

  final _accidents = StreamController<AccidentEvent>.broadcast();

  /// Accident alerts coming from the device.
  Stream<AccidentEvent> get accidents => _accidents.stream;

  String? get pairedId => _prefs.getString(_prefKey);
  String get pairedName => _prefs.getString(_prefName) ?? BleUuids.namePrefix;
  bool get isConnected => link == DeviceLink.connected;
  String? get connectedId => _device?.remoteId.str;

  // ------------------------------------------------------------------ scan
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults.map((list) =>
      list.where(_isSolveX).toList()..sort((a, b) => b.rssi.compareTo(a.rssi)));

  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  bool _isSolveX(ScanResult r) {
    final name = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : r.device.platformName;
    if (name.startsWith(BleUuids.namePrefix)) return true;
    return r.advertisementData.serviceUuids.contains(Guid(BleUuids.service));
  }

  Future<bool> isBluetoothOn() async {
    if (kIsWeb) return true;
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      final s = await FlutterBluePlus.adapterState.first;
      return s == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> turnOnBluetooth() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await FlutterBluePlus.turnOn();
      }
    } catch (_) {}
  }

  Future<void> startScan() async {
    lastError = null;
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ connect
  /// Reconnects to the last paired device, if any. Call once at startup.
  Future<void> restore() async {
    if (kIsWeb) return;
    final id = pairedId;
    if (id == null || link != DeviceLink.disconnected) return;
    _userDisconnect = false;
    await _connect(BluetoothDevice.fromId(id), name: pairedName, quiet: true);
  }

  /// Connects to a device picked from the scan list and remembers it.
  Future<bool> pair(ScanResult r) async {
    await stopScan();
    _userDisconnect = false;
    final name = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : (r.device.platformName.isNotEmpty ? r.device.platformName : BleUuids.namePrefix);
    final ok = await _connect(r.device, name: name);
    if (ok) {
      await _prefs.setString(_prefKey, r.device.remoteId.str);
      await _prefs.setString(_prefName, name);
    }
    return ok;
  }

  Future<bool> _connect(BluetoothDevice d, {required String name, bool quiet = false}) async {
    if (link == DeviceLink.connecting) return false;
    _setLink(DeviceLink.connecting);
    try {
      await d.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      _device = d;
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await d.requestMtu(185);
        } catch (_) {}
      }
      await _setup(d);
      await _connSub?.cancel();
      _connSub = d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) _onDisconnected(name);
      });
      _setLink(DeviceLink.connected);
      _reconnectTimer?.cancel();
      onLinkChanged?.call(d.remoteId.str, name, true);
      await sendVehicleType(vehicleType);
      return true;
    } catch (e) {
      if (!quiet) lastError = e.toString();
      try {
        await d.disconnect();
      } catch (_) {}
      _setLink(DeviceLink.disconnected);
      _scheduleReconnect();
      return false;
    }
  }

  Future<void> _setup(BluetoothDevice d) async {
    for (final s in _charSubs) {
      await s.cancel();
    }
    _charSubs.clear();
    _configChar = null;

    final services = await d.discoverServices();
    final svc = services.where((s) => s.uuid == Guid(BleUuids.service)).toList();
    if (svc.isEmpty) throw Exception('SolveX service not found on device');

    for (final c in svc.first.characteristics) {
      if (c.uuid == Guid(BleUuids.config)) {
        _configChar = c;
      } else if (c.uuid == Guid(BleUuids.alert)) {
        _charSubs.add(c.onValueReceived.listen(_onAlertBytes));
        d.cancelWhenDisconnected(_charSubs.last);
        await c.setNotifyValue(true);
      } else if (c.uuid == Guid(BleUuids.status)) {
        _charSubs.add(c.onValueReceived.listen(_onStatusBytes));
        d.cancelWhenDisconnected(_charSubs.last);
        await c.setNotifyValue(true);
        try {
          await c.read();
        } catch (_) {}
      }
    }
    if (_configChar == null) throw Exception('Config characteristic not found');
  }

  void _onDisconnected(String name) {
    final id = _device?.remoteId.str;
    _configChar = null;
    _setLink(DeviceLink.disconnected);
    if (id != null) onLinkChanged?.call(id, name, false);
    if (!_userDisconnect) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_userDisconnect || pairedId == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (link == DeviceLink.disconnected && !_userDisconnect) restore();
    });
  }

  /// Disconnects. With [forget], the device is unpaired.
  Future<void> disconnect({bool forget = false}) async {
    _userDisconnect = true;
    _reconnectTimer?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    if (forget) {
      await _prefs.remove(_prefKey);
      await _prefs.remove(_prefName);
      _device = null;
    }
    _setLink(DeviceLink.disconnected);
  }

  // ------------------------------------------------------------------ messages
  Future<bool> _write(Map<String, dynamic> json) async {
    final c = _configChar;
    if (c == null) return false;
    try {
      await c.write(utf8.encode(jsonEncode(json)), withoutResponse: false);
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<bool> sendVehicleType(VehicleType v) {
    vehicleType = v;
    return _write({'veh': v.wire});
  }

  /// Asks the device to fire a test alert (round trip through the hardware).
  Future<bool> sendTestAlert() => _write({'cmd': 'test'});

  /// Re-calibrates the "upright" position (vehicle parked normally).
  Future<bool> calibrate() => _write({'cmd': 'cal'});

  void _onAlertBytes(List<int> bytes) {
    final m = _decode(bytes);
    if (m == null || m['t'] != 'acc') return;
    final id = (m['id'] as num?)?.toInt();
    if (id != null) {
      _write({'cmd': 'ack', 'id': id});
      if (_seenAlertIds.contains(id)) return; // device re-sends until acked
      _seenAlertIds.add(id);
    }
    final fix = m['fix'] == 1 || m['fix'] == true;
    _accidents.add(AccidentEvent(
      trigger: (m['type'] ?? 'impact').toString(),
      gpsFix: fix,
      lat: fix ? (m['lat'] as num?)?.toDouble() : null,
      lng: fix ? (m['lng'] as num?)?.toDouble() : null,
      peakG: (m['g'] as num?)?.toDouble(),
      tilt: (m['tilt'] as num?)?.toDouble(),
      deviceId: _device?.remoteId.str,
    ));
  }

  void _onStatusBytes(List<int> bytes) {
    final m = _decode(bytes);
    if (m == null || m['t'] != 'st') return;
    final fix = m['fix'] == 1 || m['fix'] == true;
    status = DeviceStatus(
      gpsFix: fix,
      lat: fix ? (m['lat'] as num?)?.toDouble() : null,
      lng: fix ? (m['lng'] as num?)?.toDouble() : null,
      satellites: (m['sat'] as num?)?.toInt(),
      vehicleType: m['veh'] == null ? null : VehicleType.fromId(m['veh'] as String),
    );
    notifyListeners();
  }

  Map<String, dynamic>? _decode(List<int> bytes) {
    try {
      final v = jsonDecode(utf8.decode(bytes));
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  /// Injects an accident without hardware (demo / test mode).
  void simulateAccident() {
    _accidents.add(AccidentEvent(trigger: 'simulation', deviceId: _device?.remoteId.str));
  }

  void _setLink(DeviceLink l) {
    link = l;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _connSub?.cancel();
    for (final s in _charSubs) {
      s.cancel();
    }
    _accidents.close();
    super.dispose();
  }
}
