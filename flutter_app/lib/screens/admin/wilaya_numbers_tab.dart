import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// Police / civil protection numbers per wilaya (collection wilayaNumbers).
class WilayaNumbersTab extends StatefulWidget {
  const WilayaNumbersTab({super.key});

  @override
  State<WilayaNumbersTab> createState() => _WilayaNumbersTabState();
}

class _WilayaNumbersTabState extends State<WilayaNumbersTab> {
  String _q = '';
  bool _seeding = false;

  Future<void> _seed() async {
    if (!await confirmDialog(context, context.tr('seed_confirm'))) return;
    if (!mounted) return;
    final db = context.read<Db>();
    setState(() => _seeding = true);
    try {
      final n = await db.seedMissingWilayas();
      if (mounted) showSnack(context, '${context.tr('seed_done')}: $n');
    } catch (_) {
      if (mounted) showSnack(context, context.tr('err_generic'));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Db>();
    final lang = context.lang;
    return StreamBuilder<Map<int, WilayaNumbers>>(
      stream: db.wilayaNumbersMap(),
      builder: (context, snap) {
        if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final map = snap.data!;
        final missing = Wilayas.all.where((w) => !map.containsKey(w.code)).length;
        final list = Wilayas.all.where((w) {
          if (_q.isEmpty) return true;
          final q = _q.toLowerCase();
          return w.nameFr.toLowerCase().contains(q) || w.nameAr.contains(q) || '${w.code}' == q;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.tr('search_wilaya'),
                ),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            if (missing > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InfoBanner('${context.tr('wilayas_missing')}: $missing'),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _seeding ? null : _seed,
                      icon: const Icon(Icons.playlist_add),
                      label: Text(context.tr('seed_defaults')),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final w = list[i];
                  final n = map[w.code];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${w.code}')),
                    title: Text(w.name(lang)),
                    subtitle: n == null
                        ? Text(context.tr('not_configured'),
                            style: TextStyle(color: Theme.of(context).colorScheme.error))
                        : Text('${context.tr('police')}: ${n.police.isEmpty ? '—' : n.police}\n'
                            '${context.tr('civil_protection')}: ${n.civilProtection.isEmpty ? '—' : n.civilProtection}'),
                    isThreeLine: n != null,
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _edit(context, w, n),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, Wilaya w, WilayaNumbers? n) async {
    final db = context.read<Db>();
    final form = GlobalKey<FormState>();
    final police = TextEditingController(text: n?.police);
    final civil = TextEditingController(text: n?.civilProtection);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(w.label(d.lang)),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: police,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: d.tr('police'),
                  prefixIcon: const Icon(Icons.local_police),
                ),
                validator: (v) => (v == null || !isValidPhone(v)) ? d.tr('err_phone') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: civil,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: d.tr('civil_protection'),
                  prefixIcon: const Icon(Icons.fire_truck),
                ),
                validator: (v) => (v == null || !isValidPhone(v)) ? d.tr('err_phone') : null,
              ),
              const SizedBox(height: 8),
              Text(d.tr('numbers_sms_note'), style: Theme.of(d).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(d.tr('cancel'))),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(d, true);
            },
            child: Text(d.tr('save')),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await db.setWilayaNumbers(w.code, police.text.trim(), civil.text.trim());
      } catch (_) {
        if (context.mounted) showSnack(context, context.tr('err_generic'));
      }
    }
    police.dispose();
    civil.dispose();
  }
}
