import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../common/alert_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final db = context.read<Db>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('my_alerts'))),
      body: StreamBuilder<List<AlertModel>>(
        stream: db.alertsOf(user.uid),
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return EmptyState(Icons.history, context.tr('no_alerts'));
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => AlertTile(alert: list[i], admin: false),
          );
        },
      ),
    );
  }
}

/// Row used in the user history and the admin alert list.
class AlertTile extends StatelessWidget {
  final AlertModel alert;
  final bool admin;

  const AlertTile({super.key, required this.alert, required this.admin});

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final lang = context.lang;
    final subtitle = [
      Wilayas.byCode(a.wilayaCode)?.label(lang) ?? '—',
      context.tr(a.vehicleType == VehicleType.car ? 'car' : 'motorcycle'),
      if (admin) a.userName,
      if (a.testMode) 'TEST',
    ].join(' • ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(a.vehicleType == VehicleType.car ? Icons.directions_car : Icons.two_wheeler),
      ),
      title: Text(formatDateTime(a.createdAt)),
      subtitle: Text(subtitle),
      trailing: StatusChip(a.status),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlertDetailScreen(alertId: a.id, admin: admin)),
      ),
    );
  }
}
