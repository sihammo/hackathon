import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../user/history_screen.dart';

/// All alerts with filters: date, wilaya, vehicle type, status.
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  DateTimeRange? _range;
  int? _wilaya;
  VehicleType? _vehicle;
  String? _status;

  bool get _hasFilters => _range != null || _wilaya != null || _vehicle != null || _status != null;

  bool _match(AlertModel a) {
    if (_range != null) {
      final d = a.createdAt;
      if (d == null) return false;
      final end = _range!.end.add(const Duration(days: 1));
      if (d.isBefore(_range!.start) || !d.isBefore(end)) return false;
    }
    if (_wilaya != null && a.wilayaCode != _wilaya) return false;
    if (_vehicle != null && a.vehicleType != _vehicle) return false;
    if (_status != null && a.status != _status) return false;
    return true;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              FilterChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(_range == null
                    ? context.tr('filter_date')
                    : '${formatDate(_range!.start)} → ${formatDate(_range!.end)}'),
                selected: _range != null,
                onSelected: (_) => _pickRange(),
              ),
              const SizedBox(width: 8),
              _menu<int>(
                icon: Icons.location_city,
                label: _wilaya == null ? context.tr('wilaya') : Wilayas.byCode(_wilaya)!.label(lang),
                selected: _wilaya != null,
                items: {for (final w in Wilayas.all) w.code: w.label(lang)},
                onSelected: (v) => setState(() => _wilaya = v),
              ),
              const SizedBox(width: 8),
              _menu<VehicleType>(
                icon: Icons.directions_car,
                label: _vehicle == null
                    ? context.tr('vehicle_type')
                    : context.tr(_vehicle == VehicleType.car ? 'car' : 'motorcycle'),
                selected: _vehicle != null,
                items: {
                  VehicleType.car: context.tr('car'),
                  VehicleType.motorcycle: context.tr('motorcycle'),
                },
                onSelected: (v) => setState(() => _vehicle = v),
              ),
              const SizedBox(width: 8),
              _menu<String>(
                icon: Icons.flag_outlined,
                label: _status == null ? context.tr('status') : context.tr('status_$_status'),
                selected: _status != null,
                items: {for (final s in AlertStatus.all) s: context.tr('status_$s')},
                onSelected: (v) => setState(() => _status = v),
              ),
              if (_hasFilters) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 18),
                  label: Text(context.tr('clear_filters')),
                  onPressed: () => setState(() {
                    _range = null;
                    _wilaya = null;
                    _vehicle = null;
                    _status = null;
                  }),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AlertModel>>(
            stream: context.read<Db>().allAlerts(),
            builder: (context, snap) {
              if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!.where(_match).toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('${list.length} ${context.tr('results')}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? EmptyState(Icons.search_off, context.tr('no_alerts'))
                        : ListView.separated(
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (c, i) => AlertTile(alert: list[i], admin: true),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _menu<T>({
    required IconData icon,
    required String label,
    required bool selected,
    required Map<T, String> items,
    required ValueChanged<T?> onSelected,
  }) {
    return PopupMenuButton<Object>(
      onSelected: (v) => onSelected(v == '__all__' ? null : v as T),
      itemBuilder: (c) => [
        PopupMenuItem<Object>(value: '__all__', child: Text(c.tr('all'))),
        for (final e in items.entries) PopupMenuItem<Object>(value: e.key as Object, child: Text(e.value)),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        backgroundColor: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      ),
    );
  }
}
