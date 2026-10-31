import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/wilayas.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// View, search, create, delete, and disable user accounts.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  static Future<void> showCreateUserDialog(BuildContext context) =>
      _UsersTabState._showCreateUserDialog(context);

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
    final theme = Theme.of(context);

    return Column(
      children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.tr('search_users'),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Text(
                  context.tr('nav_users'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(
                    context.tr('clear_all_users'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _confirmClearAll(context, me?.uid),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: db.allUsers(),
              builder: (context, snap) {
                if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!.where(_match).toList();
                if (list.isEmpty) return EmptyState(Icons.person_search, context.tr('no_users'));

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 84),
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
                      title: Text(
                        u.fullName,
                        style: TextStyle(
                          decoration: u.disabled ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text([
                        '@${u.username}',
                        u.phone,
                        Wilayas.byCode(u.wilayaCode)?.label(lang) ?? '',
                        if (u.isAdmin) context.tr('role_admin'),
                      ].join(' • ')),
                      isThreeLine: false,
                      trailing: (u.isAdmin || isMe)
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.tr('role_admin'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
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
                                IconButton(
                                  tooltip: context.tr('delete_user'),
                                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                  onPressed: () => _confirmDeleteUser(context, u),
                                ),
                              ],
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

  Future<void> _confirmClearAll(BuildContext context, String? myUid) async {
    final db = context.read<Db>();
    final ok = await confirmDialog(context, context.tr('clear_all_users_confirm'));
    if (!ok) return;

    try {
      await db.clearAllUsers(currentAdminUid: myUid ?? '');
      if (context.mounted) {
        showSnack(context, context.tr('clear_all_users_done'));
      }
    } catch (_) {
      if (context.mounted) {
        showSnack(context, context.tr('err_generic'));
      }
    }
  }

  Future<void> _confirmDeleteUser(BuildContext context, AppUser u) async {
    final db = context.read<Db>();
    final ok = await confirmDialog(
      context,
      '${context.tr('delete_user_confirm')}\n${u.fullName} (@${u.username})',
    );
    if (!ok) return;

    try {
      await db.deleteUser(u.uid);
      if (context.mounted) {
        showSnack(context, context.tr('user_deleted'));
      }
    } catch (_) {
      if (context.mounted) {
        showSnack(context, context.tr('err_generic'));
      }
    }
  }

  static Future<void> _showCreateUserDialog(BuildContext context) async {
    final db = context.read<Db>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    int wilayaCode = 16;
    VehicleType vehicle = VehicleType.car;
    String role = 'user';

    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, setDState) {
          final lang = context.lang;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person_add),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('create_user_title'))),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('full_name'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? context.tr('err_required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: InputDecoration(
                        labelText: context.tr('username'),
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return context.tr('err_required');
                        if (v.trim().length < 3) return context.tr('err_username_format');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.tr('password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return context.tr('err_required');
                        if (v.length < 4) return context.tr('err_weak_password');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('phone'),
                        prefixIcon: const Icon(Icons.phone),
                        hintText: '0555 12 34 56',
                      ),
                      validator: (v) =>
                          (v == null || !isValidPhone(v)) ? context.tr('err_phone') : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: wilayaCode,
                      decoration: InputDecoration(
                        labelText: context.tr('wilaya'),
                        prefixIcon: const Icon(Icons.location_city),
                      ),
                      items: Wilayas.all
                          .map((w) => DropdownMenuItem(
                                value: w.code,
                                child: Text('${w.code} - ${w.label(lang)}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDState(() => wilayaCode = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<VehicleType>(
                      initialValue: vehicle,
                      decoration: InputDecoration(
                        labelText: context.tr('vehicle_type'),
                        prefixIcon: const Icon(Icons.directions_car),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: VehicleType.car,
                          child: Text(context.tr('car')),
                        ),
                        DropdownMenuItem(
                          value: VehicleType.motorcycle,
                          child: Text(context.tr('motorcycle')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDState(() => vehicle = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: InputDecoration(
                        labelText: context.tr('role'),
                        prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'user',
                          child: Text(context.tr('role_user')),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(context.tr('role_admin')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDState(() => role = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(),
                child: Text(context.tr('cancel')),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await db.createUserByAdmin(
                      fullName: nameCtrl.text.trim(),
                      username: usernameCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      wilayaCode: wilayaCode,
                      vehicleType: vehicle,
                      role: role,
                    );
                    if (d.mounted) Navigator.of(d).pop();
                    if (context.mounted) {
                      showSnack(context, context.tr('user_created'));
                    }
                  } catch (e) {
                    final errStr = e.toString();
                    final key = errStr.contains('err_username_taken')
                        ? 'err_username_taken'
                        : 'err_generic';
                    if (context.mounted) {
                      showSnack(context, context.tr(key));
                    }
                  }
                },
                child: Text(context.tr('save')),
              ),
            ],
          );
        },
      ),
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
