/// Shared constants for SolveX Alert.
library;

/// BLE GATT layout exposed by the SolveX ESP32 device.
/// Must match firmware/solvex_device/solvex_device.ino and docs/BLE_PROTOCOL.md.
class BleUuids {
  static const service = '5a0e0001-7b2c-4e3d-9f10-a1e2c3d4e5f6';

  /// Device -> app (notify): accident alerts as JSON.
  static const alert = '5a0e0002-7b2c-4e3d-9f10-a1e2c3d4e5f6';

  /// Device -> app (notify + read): periodic status (GPS fix, vehicle type).
  static const status = '5a0e0003-7b2c-4e3d-9f10-a1e2c3d4e5f6';

  /// App -> device (write): configuration and commands as JSON.
  static const config = '5a0e0004-7b2c-4e3d-9f10-a1e2c3d4e5f6';

  /// Advertised name prefix of SolveX devices.
  static const namePrefix = 'SolveX';
}

/// Vehicle the device is installed on.
enum VehicleType {
  car,
  motorcycle;

  /// Value stored in Firestore.
  String get id => name;

  /// Value sent to the device over BLE.
  String get wire => this == VehicleType.car ? 'car' : 'moto';

  static VehicleType fromId(String? v) =>
      (v == 'motorcycle' || v == 'moto') ? VehicleType.motorcycle : VehicleType.car;
}

/// Alert lifecycle. `cancelled` = user pressed "I'm OK" during the countdown.
class AlertStatus {
  static const cancelled = 'cancelled';
  static const sent = 'sent';
  static const received = 'received';
  static const dispatched = 'dispatched';
  static const arrived = 'arrived';
  static const resolved = 'resolved';

  /// Ordered response stages for police / civil protection.
  static const stages = [sent, received, dispatched, arrived, resolved];

  static const all = [cancelled, ...stages];

  static int indexOf(String s) => stages.indexOf(s);

  /// Next stage after [s], or null if already resolved.
  static String? next(String s) {
    final i = stages.indexOf(s);
    if (i < 0 || i >= stages.length - 1) return null;
    return stages[i + 1];
  }
}

/// Emergency services that respond to an alert.
class EmergencyServiceType {
  static const police = 'police';
  static const civil = 'civil';
  static const all = [police, civil];
}

class AppConstants {
  /// Countdown before the alert is sent automatically.
  static const countdownSeconds = 15;

  /// Firebase Auth needs an email: usernames are mapped to `<username>@<domain>`.
  /// Users never see or use this address.
  static const usernameDomain = 'users.solvexalert.app';

  /// Center of Algeria for maps.
  static const algeriaLat = 28.0;
  static const algeriaLng = 2.6;

  static const appVersion = '1.0.0';
}
