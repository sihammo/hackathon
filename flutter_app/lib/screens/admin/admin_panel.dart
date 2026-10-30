import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../common/hotspot_map.dart';
import 'alerts_tab.dart';
import 'dashboard_tab.dart';
import 'users_tab.dart';
import 'wilaya_numbers_tab.dart';

/// Admin-only shell. Reached from the same login screen when users/{uid}.role == 'admin'.
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('admin_dashboard'),
      context.tr('admin_alerts'),
      context.tr('admin_map'),
      context.tr('admin_users'),
      context.tr('admin_wilayas'),
    ];
    final pages = const [
      DashboardTab(),
      AlertsTab(),
      _AdminMap(),
      UsersTab(),
      WilayaNumbersTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 26, height: 26, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Flexible(child: Text(titles[_tab], overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('nav_settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: context.tr('admin_dashboard')),
          NavigationDestination(icon: const Icon(Icons.notifications_active_outlined), selectedIcon: const Icon(Icons.notifications_active), label: context.tr('admin_alerts')),
          NavigationDestination(icon: const Icon(Icons.map_outlined), selectedIcon: const Icon(Icons.map), label: context.tr('admin_map')),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: context.tr('admin_users')),
          NavigationDestination(icon: const Icon(Icons.local_phone_outlined), selectedIcon: const Icon(Icons.local_phone), label: context.tr('admin_wilayas')),
        ],
      ),
    );
  }
}

class _AdminMap extends StatelessWidget {
  const _AdminMap();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlertModel>>(
      stream: context.read<Db>().allAlerts(),
      builder: (context, snap) {
        final pts = (snap.data ?? const <AlertModel>[])
            .where((a) => a.hasLocation && !a.isCancelled)
            .map((a) => LatLng(a.lat!, a.lng!))
            .toList();
        return Stack(
          children: [
            AccidentMap(points: pts),
            Positioned(
              top: 12,
              left: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('${context.tr('hotspots_legend')} (${pts.length})'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Db>();
    final user = context.watch<SessionController>().user;
    final lc = context.watch<LocaleController>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav_settings'))),
      body: StreamBuilder<AppConfig>(
        stream: db.config(),
        builder: (context, snap) {
          final cfg = snap.data ?? AppConfig.defaults;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: context.tr('test_mode'),
                icon: Icons.science_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('force_test_mode')),
                      subtitle: Text(context.tr('force_test_mode_desc')),
                      value: cfg.forceTestMode,
                      onChanged: (v) async {
                        if (!v &&
                            !await confirmDialog(context, context.tr('test_mode_off_confirm'))) {
                          return;
                        }
                        await db.setConfig(forceTestMode: v);
                      },
                    ),
                    _DefaultTestNumber(initial: cfg.defaultTestNumber),
                  ],
                ),
              ),
              SectionCard(
                title: context.tr('language'),
                icon: Icons.translate,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'fr', label: Text('Français')),
                  ],
                  selected: {lc.lang},
                  onSelectionChanged: (s) => lc.setLanguage(s.first),
                ),
              ),
              if (user != null)
                SectionCard(
                  title: context.tr('profile'),
                  icon: Icons.admin_panel_settings_outlined,
                  child: Column(
                    children: [
                      InfoRow(context.tr('full_name'), user.fullName),
                      InfoRow(context.tr('username'), user.username),
                      InfoRow(context.tr('role'), context.tr('role_admin')),
                    ],
                  ),
                ),
              FilledButton.tonalIcon(
                onPressed: () async {
                  if (!await confirmDialog(context, context.tr('logout_confirm'))) return;
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await context.read<SessionController>().signOut();
                },
                icon: const Icon(Icons.logout),
                label: Text(context.tr('logout')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DefaultTestNumber extends StatefulWidget {
  final String initial;
  const _DefaultTestNumber({required this.initial});

  @override
  State<_DefaultTestNumber> createState() => _DefaultTestNumberState();
}

class _DefaultTestNumberState extends State<_DefaultTestNumber> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('default_test_number'),
              helperText: context.tr('default_test_number_desc'),
              helperMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.save),
          onPressed: () async {
            final v = _c.text.trim();
            if (v.isNotEmpty && !isValidPhone(v)) {
              showSnack(context, context.tr('err_phone'));
              return;
            }
            await context.read<Db>().setConfig(defaultTestNumber: v);
            if (context.mounted) showSnack(context, context.tr('saved'));
          },
        ),
      ],
    );
  }
}
