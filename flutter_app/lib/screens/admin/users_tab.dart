import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// View, search and disable user accounts.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  String _q = '';

  bool _match(AppUser u) {
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return u.fullName.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q) ||
        u.phone.contains(q) ||
        Wilayas.nameOf(u.wilayaCode, 'fr').toLowerCase().contains(q) ||
        Wilayas.nameOf(u.wilayaCode, 'ar').contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionController>().user;
    final db = context.read<Db>();
    final lang = context.lang;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr('search_users'),
            ),
            onChanged: (v) => setState(() => _q = v.trim()),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AppUser>>(
            stream: db.allUsers(),
            builder: (context, snap) {
              if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!.where(_match).toList();
              if (list.isEmpty) return EmptyState(Icons.person_search, context.tr('no_users'));
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = list[i];
                  final isMe = u.uid == me?.uid;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.disabled ? Colors.grey : null,
                      child: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person),
                    ),
                    title: Text(u.fullName,
                        style: TextStyle(
                            decoration: u.disabled ? TextDecoration.lineThrough : null)),
                    subtitle: Text([
                      '@${u.username}',
                      u.phone,
                      Wilayas.byCode(u.wilayaCode)?.label(lang) ?? '',
                      if (u.isAdmin) context.tr('role_admin'),
                    ].join(' • ')),
                    isThreeLine: false,
                    trailing: (u.isAdmin || isMe)
                        ? null
                        : Switch(
                            value: !u.disabled,
                            onChanged: (active) async {
                              final msg = context.tr(active ? 'enable_user_confirm' : 'disable_user_confirm');
                              if (!await confirmDialog(context, '$msg\n${u.fullName}')) return;
                              try {
                                await db.setUserDisabled(u.uid, !active);
                              } catch (_) {
                                if (context.mounted) showSnack(context, context.tr('err_generic'));
                              }
                            },
                          ),
                    onTap: () => _details(context, u),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _details(BuildContext context, AppUser u) {
    final lang = context.lang;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoRow(c.tr('full_name'), u.fullName),
            InfoRow(c.tr('username'), u.username),
            InfoRow(c.tr('phone'), u.phone),
            InfoRow(c.tr('wilaya'), Wilayas.byCode(u.wilayaCode)?.label(lang) ?? '—'),
            InfoRow(c.tr('vehicle_type'), c.tr(u.vehicleType.id)),
            InfoRow(c.tr('role'), c.tr(u.isAdmin ? 'role_admin' : 'role_user')),
            InfoRow(c.tr('created_at'), formatDateTime(u.createdAt)),
            InfoRow(c.tr('test_mode'), c.tr(u.testMode ? 'yes' : 'no')),
            InfoRow(c.tr('status'), c.tr(u.disabled ? 'disabled' : 'active')),
          ],
        ),
      ),
    );
  }
}
