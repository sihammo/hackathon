import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/ble_service.dart';
import '../../services/db.dart';
import '../common/hotspot_map.dart';
import 'alarm_screen.dart';
import 'contacts_screen.dart';
import 'history_screen.dart';
import 'home_tab.dart';
import 'settings_screen.dart';

/// Shell for regular users: bottom navigation + global accident listener.
class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _tab = 0;
  StreamSubscription<AccidentEvent>? _accSub;
  late final BleService _ble;

  @override
  void initState() {
    super.initState();
    _ble = context.read<BleService>();
    final db = context.read<Db>();
    final session = context.read<SessionController>();

    _ble.vehicleType = session.user?.vehicleType ?? _ble.vehicleType;
    _ble.onLinkChanged = (remoteId, name, connected) {
      final u = session.user;
      if (u == null) return;
      db
          .upsertDevice(
            deviceId: Db.deviceIdFromRemote(remoteId),
            uid: u.uid,
            name: name,
            vehicleType: u.vehicleType,
            connected: connected,
          )
          .catchError((_) {});
    };
    _accSub = _ble.accidents.listen((e) {
      if (mounted) AlarmScreen.show(context, e);
    });
    // Reconnect to the paired box after the first frame (avoids notifying during build).
    WidgetsBinding.instance.addPostFrameCallback((_) => _ble.restore());
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _ble.onLinkChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null) return const SizedBox.shrink();

    final pages = <Widget>[
      const HomeTab(),
      HotspotMapPage(title: context.tr('nav_map')),
      const HistoryScreen(),
      const ContactsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: context.tr('nav_home')),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: context.tr('nav_map')),
          NavigationDestination(icon: const Icon(Icons.history), label: context.tr('nav_history')),
          NavigationDestination(icon: const Icon(Icons.contacts_outlined), selectedIcon: const Icon(Icons.contacts), label: context.tr('nav_contacts')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: context.tr('nav_settings')),
        ],
      ),
    );
  }
}
