import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user!;
    final db = context.read<Db>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('emergency_contacts'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, user.uid, null),
        icon: const Icon(Icons.person_add),
        label: Text(context.tr('add_contact')),
      ),
      body: StreamBuilder<List<EmergencyContact>>(
        stream: db.contactsOf(user.uid),
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(Icons.error_outline, context.tr('err_generic'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(Icons.contact_phone_outlined, context.tr('no_contacts'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('contacts_desc')),
                );
              }
              final c = list[i - 1];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(c.name.isNotEmpty ? c.name.characters.first.toUpperCase() : '?'),
                ),
                title: Text(c.name),
                subtitle: Text([c.phone, if (c.relation.isNotEmpty) c.relation].join(' • ')),
                onTap: () => _edit(context, user.uid, c),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDialog(context, context.tr('delete_contact_confirm'))) {
                      await db.deleteContact(c.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, String uid, EmergencyContact? c) async {
    final db = context.read<Db>();
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: c?.name);
    final phone = TextEditingController(text: c?.phone);
    final relation = TextEditingController(text: c?.relation);

    final saved = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(d.tr(c == null ? 'add_contact' : 'edit_contact')),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: d.tr('contact_name')),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? d.tr('err_required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: d.tr('phone')),
                validator: (v) =>
                    (v == null || !isValidPhone(v)) ? d.tr('err_phone') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: relation,
                decoration: InputDecoration(
                  labelText: d.tr('relation'),
                  hintText: d.tr('relation_hint'),
                ),
              ),
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

    if (saved == true) {
      try {
        if (c == null) {
          await db.addContact(uid, name.text.trim(), phone.text.trim(), relation.text.trim());
        } else {
          await db.updateContact(c, name.text.trim(), phone.text.trim(), relation.text.trim());
        }
      } catch (_) {
        if (context.mounted) showSnack(context, context.tr('err_generic'));
      }
    }
    name.dispose();
    phone.dispose();
    relation.dispose();
  }
}
