import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth.dart';
import '../../services/ble_service.dart';
import '../../services/db.dart';
import '../../services/location_service.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user!;
    final db = context.read<Db>();
    final lc = context.watch<LocaleController>();
    final isArabic = lc.lang == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav_settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: context.tr('profile'),
            icon: Icons.person_outline,
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editProfile(context, user),
            ),
            child: Column(
              children: [
                Center(
                  child: Tooltip(
                    message: isArabic ? 'اضغط لتغيير الصورة' : 'Cliquer pour changer la photo',
                    child: InkWell(
                      onTap: () => showAvatarPicker(context),
                      borderRadius: BorderRadius.circular(44),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.brand, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: const Color(0xFFE2E8F0),
                              backgroundImage: getUserAvatarProvider(user.effectiveAvatar),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => showAvatarPicker(context),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 15),
                  label: Text(
                    isArabic ? 'تغيير الصورة' : 'Changer la photo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                InfoRow(context.tr('full_name'), user.fullName),
                InfoRow(context.tr('username'), user.username),
                InfoRow(context.tr('phone'), user.phone),
              ],
            ),
          ),
          SectionCard(
            title: context.tr('wilaya'),
            icon: Icons.location_city_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WilayaDropdown(
                  value: user.wilayaCode,
                  onChanged: (v) {
                    if (v != null) db.updateUser(user.uid, {'wilayaCode': v});
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: Text(context.tr('detect_wilaya')),
                  onPressed: () async {
                    final w = await context.read<LocationService>().detectWilaya();
                    if (!context.mounted) return;
                    if (w == null) {
                      showSnack(context, context.tr('location_unavailable'));
                    } else {
                      await db.updateUser(user.uid, {'wilayaCode': w.code});
                      if (context.mounted) {
                        showSnack(context, '${context.tr('wilaya')}: ${w.label(context.lang)}');
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          SectionCard(
            title: context.tr('test_mode'),
            icon: Icons.science_outlined,
            child: StreamBuilder<AppConfig>(
              stream: db.config(),
              builder: (context, snap) {
                final cfg = snap.data ?? AppConfig.defaults;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('test_mode')),
                      subtitle: Text(context.tr('test_mode_desc')),
                      value: user.testMode || cfg.forceTestMode,
                      onChanged: cfg.forceTestMode
                          ? null
                          : (v) async {
                              if (!v &&
                                  !await confirmDialog(context, context.tr('test_mode_off_confirm'))) {
                                return;
                              }
                              await db.updateUser(user.uid, {'testMode': v});
                            },
                    ),
                    if (cfg.forceTestMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(context.tr('test_mode_forced'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    _TestNumberField(user: user, fallback: cfg.defaultTestNumber),
                  ],
                );
              },
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
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () async {
              if (!await confirmDialog(context, context.tr('logout_confirm'))) return;
              if (!context.mounted) return;
              await context.read<BleService>().disconnect();
              if (context.mounted) await context.read<SessionController>().signOut();
            },
            icon: const Icon(Icons.logout),
            label: Text(context.tr('logout')),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Slamtek v${AppConstants.appVersion}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, AppUser user) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: user.fullName);
    final phone = TextEditingController(text: user.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(d.tr('profile')),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: InputDecoration(labelText: d.tr('full_name')),
                validator: (v) => (v == null || v.trim().isEmpty) ? d.tr('err_required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: d.tr('phone')),
                validator: (v) => (v == null || !isValidPhone(v)) ? d.tr('err_phone') : null,
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
    if (ok == true && context.mounted) {
      await context.read<SessionController>().updateUser({
        'fullName': name.text.trim(),
        'phone': phone.text.trim(),
      });
    }
    name.dispose();
    phone.dispose();
  }
}

class _TestNumberField extends StatefulWidget {
  final AppUser user;
  final String fallback;
  const _TestNumberField({required this.user, required this.fallback});

  @override
  State<_TestNumberField> createState() => _TestNumberFieldState();
}

class _TestNumberFieldState extends State<_TestNumberField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.user.testPhoneNumber);

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
              labelText: context.tr('test_number'),
              helperText: widget.fallback.isNotEmpty
                  ? '${context.tr('default')}: ${widget.fallback}'
                  : context.tr('test_number_hint'),
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
            await context.read<Db>().updateUser(widget.user.uid, {'testPhoneNumber': v});
            if (context.mounted) showSnack(context, context.tr('saved'));
          },
        ),
      ],
    );
  }
}
