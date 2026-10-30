import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../services/ble_service.dart';
import '../../services/emergency_service.dart';
import '../../widgets/common.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  late final BleService _ble;
  bool _btOn = true;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _ble = context.read<BleService>();
    _start();
  }

  Future<void> _start() async {
    await context.read<EmergencyService>().requestPermissions();
    _btOn = await _ble.isBluetoothOn();
    if (!_btOn) {
      await _ble.turnOnBluetooth();
      _btOn = await _ble.isBluetoothOn();
    }
    if (mounted) setState(() {});
    if (_btOn) await _ble.startScan();
  }

  @override
  void dispose() {
    _ble.stopScan();
    super.dispose();
  }

  Future<void> _pair(ScanResult r) async {
    setState(() => _connectingId = r.device.remoteId.str);
    final ok = await _ble.pair(r);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ok) {
      showSnack(context, context.tr('device_paired'));
      Navigator.of(context).pop();
    } else {
      showSnack(context, context.tr('connection_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('pair_device')),
        actions: [
          if (ble.pairedId != null)
            IconButton(
              tooltip: context.tr('forget_device'),
              icon: const Icon(Icons.link_off),
              onPressed: () async {
                if (await confirmDialog(context, context.tr('forget_device_confirm'))) {
                  await ble.disconnect(forget: true);
                }
              },
            ),
        ],
      ),
      body: !_btOn
          ? EmptyState(Icons.bluetooth_disabled, context.tr('bluetooth_off'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('scan_hint'), textAlign: TextAlign.center),
                ),
                StreamBuilder<bool>(
                  stream: ble.isScanning,
                  initialData: false,
                  builder: (c, s) => s.data == true
                      ? const LinearProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: OutlinedButton.icon(
                            onPressed: ble.startScan,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.tr('scan_again')),
                          ),
                        ),
                ),
                Expanded(
                  child: StreamBuilder<List<ScanResult>>(
                    stream: ble.scanResults,
                    initialData: const [],
                    builder: (c, s) {
                      final list = s.data ?? const [];
                      if (list.isEmpty) {
                        return EmptyState(Icons.sensors_off, context.tr('no_device_found'));
                      }
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final r = list[i];
                          final name = r.advertisementData.advName.isNotEmpty
                              ? r.advertisementData.advName
                              : r.device.platformName;
                          final id = r.device.remoteId.str;
                          final isCurrent = ble.connectedId == id && ble.isConnected;
                          return ListTile(
                            leading: const Icon(Icons.sensors, size: 32),
                            title: Text(name.isEmpty ? id : name),
                            subtitle: Text('$id • ${r.rssi} dBm'),
                            trailing: _connectingId == id
                                ? const SizedBox(
                                    width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : (isCurrent
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : FilledButton(
                                        onPressed: _connectingId == null ? () => _pair(r) : null,
                                        child: Text(context.tr('connect')),
                                      )),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
