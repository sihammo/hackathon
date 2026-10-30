import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'hotspot_map.dart';

/// Alert details. Admins can move police / civil protection through
/// Sent → Received → Team dispatched → Arrived → Resolved.
class AlertDetailScreen extends StatelessWidget {
  final String alertId;
  final bool admin;

  const AlertDetailScreen({super.key, required this.alertId, required this.admin});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Db>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('alert_details'))),
      body: StreamBuilder<AlertModel?>(
        stream: db.alert(alertId),
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final a = snap.data!;
          final lang = context.lang;
          final point = a.hasLocation ? LatLng(a.lat!, a.lng!) : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (point != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 240,
                    child: AccidentMap(points: const [], center: point, zoom: 14, highlight: point),
                  ),
                )
              else
                InfoBanner(context.tr('location_unavailable'), icon: Icons.location_off),
              const SizedBox(height: 12),
              SectionCard(
                title: context.tr('summary'),
                icon: Icons.info_outline,
                trailing: StatusChip(a.status),
                child: Column(
                  children: [
                    InfoRow(context.tr('date'), formatDateTime(a.createdAt)),
                    if (admin) InfoRow(context.tr('full_name'), a.userName),
                    if (admin) InfoRow(context.tr('phone'), a.userPhone),
                    InfoRow(context.tr('wilaya'), Wilayas.byCode(a.wilayaCode)?.label(lang) ?? '—'),
                    InfoRow(context.tr('vehicle_type'),
                        context.tr(a.vehicleType == VehicleType.car ? 'car' : 'motorcycle')),
                    InfoRow(context.tr('trigger'), context.tr('trigger_${a.trigger}')),
                    if (a.peakG != null) InfoRow(context.tr('peak_g'), '${a.peakG!.toStringAsFixed(1)} g'),
                    if (a.tilt != null) InfoRow(context.tr('tilt'), '${a.tilt!.toStringAsFixed(0)}°'),
                    if (a.testMode) InfoRow(context.tr('test_mode'), context.tr('yes')),
                    if (!a.isCancelled)
                      InfoRow(context.tr('response_time'), formatDuration(a.responseTime)),
                    if (admin && a.notifiedNumbers.isNotEmpty)
                      InfoRow(context.tr('sms_sent_to'), a.notifiedNumbers.join(', ')),
                    if (point != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: Text(context.tr('open_in_maps')),
                          onPressed: () => launchUrl(
                            Uri.parse('https://maps.google.com/?q=${a.lat},${a.lng}'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!a.isCancelled)
                for (final s in EmergencyServiceType.all)
                  _ServiceCard(alert: a, service: s, admin: admin),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final AlertModel alert;
  final String service;
  final bool admin;

  const _ServiceCard({required this.alert, required this.service, required this.admin});

  @override
  Widget build(BuildContext context) {
    final r = alert.response(service);
    final current = AlertStatus.indexOf(r.status);
    final next = AlertStatus.next(r.status);
    return SectionCard(
      title: context.tr(service == EmergencyServiceType.police ? 'police' : 'civil_protection'),
      icon: service == EmergencyServiceType.police ? Icons.local_police : Icons.fire_truck,
      trailing: StatusChip(r.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < AlertStatus.stages.length; i++)
            _stageRow(context, AlertStatus.stages[i], i <= current, r.timestamps[AlertStatus.stages[i]]),
          const SizedBox(height: 4),
          InfoRow(context.tr('response_time'), formatDuration(r.responseTime(alert.createdAt))),
          if (admin && next != null) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.arrow_forward),
              label: Text('${context.tr('mark_as')} « ${context.tr('status_$next')} »'),
              onPressed: () async {
                try {
                  await context.read<Db>().setServiceStatus(alert.id, service, next);
                } catch (_) {
                  if (context.mounted) showSnack(context, context.tr('err_generic'));
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageRow(BuildContext context, String stage, bool done, DateTime? at) {
    final c = done ? AppColors.forStatus(stage) : Theme.of(context).disabledColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr('status_$stage'))),
          Text(at == null ? '' : formatDateTime(at), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
