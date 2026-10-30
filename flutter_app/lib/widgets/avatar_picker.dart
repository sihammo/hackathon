import 'dart:convert';
import 'dart:js_interop' as js_util;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/auth.dart';
import 'common.dart';

@js_util.JS('openAvatarPicker')
external void _jsOpenAvatarPicker(js_util.JSString callbackName);

@js_util.JS('onAvatarPickedResult')
external set _jsOnAvatarPickedResult(js_util.JSFunction fn);

/// Converts a path, base64 data URI, or web URL into a valid Flutter [ImageProvider].
ImageProvider getUserAvatarProvider(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) {
    return const AssetImage('assets/images/karim.jpg');
  }

  if (avatarUrl.startsWith('data:image')) {
    try {
      final base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (_) {
      return const AssetImage('assets/images/karim.jpg');
    }
  }

  if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
    return NetworkImage(avatarUrl);
  }

  return AssetImage(avatarUrl);
}

class PresetAvatar {
  final String id;
  final String titleFr;
  final String titleAr;
  final String subtitleFr;
  final String subtitleAr;
  final String imagePath;
  final IconData vehicleIcon;
  final String vehicleType;

  const PresetAvatar({
    required this.id,
    required this.titleFr,
    required this.titleAr,
    required this.subtitleFr,
    required this.subtitleAr,
    required this.imagePath,
    required this.vehicleIcon,
    required this.vehicleType,
  });
}

const List<PresetAvatar> presetAvatars = [
  PresetAvatar(
    id: 'karim',
    titleFr: 'Karim (Cadre)',
    titleAr: 'كريم (سائق سيارة)',
    subtitleFr: 'Voiture Berline',
    subtitleAr: 'سيارة سياحية',
    imagePath: 'assets/images/karim.jpg',
    vehicleIcon: Icons.directions_car,
    vehicleType: 'car',
  ),
  PresetAvatar(
    id: 'moto',
    titleFr: 'Biker Motard',
    titleAr: 'سائق دراجة نارية',
    subtitleFr: 'Moto Alpinestars',
    subtitleAr: 'دراجة نارية مع خوذة',
    imagePath: 'assets/images/driver_moto.jpg',
    vehicleIcon: Icons.two_wheeler,
    vehicleType: 'motorcycle',
  ),
  PresetAvatar(
    id: 'woman',
    titleFr: 'Conductrice',
    titleAr: 'سائقة سيارة',
    subtitleFr: 'Femme au volant',
    subtitleAr: 'سيارة خفيفة',
    imagePath: 'assets/images/driver_woman.jpg',
    vehicleIcon: Icons.directions_car,
    vehicleType: 'car',
  ),
  PresetAvatar(
    id: 'casual',
    titleFr: 'Conducteur Casual',
    titleAr: 'سائق حضري',
    subtitleFr: 'Polo Urbain (Alger)',
    subtitleAr: 'نمط كاجوال جزائري',
    imagePath: 'assets/images/driver_casual.jpg',
    vehicleIcon: Icons.drive_eta,
    vehicleType: 'car',
  ),
];

/// Displays a bottom sheet allowing the user to change their profile picture.
Future<void> showAvatarPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AvatarPickerSheet(),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet();

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  final _urlController = TextEditingController();
  bool _showUrlField = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupWebUploadListener();
    }
  }

  void _setupWebUploadListener() {
    try {
      _jsOnAvatarPickedResult = ((js_util.JSString dataUrl) {
        final dartString = dataUrl.toDart;
        if (mounted && dartString.isNotEmpty) {
          _selectAvatar(dartString);
        }
      }).toJS;
    } catch (_) {}
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _selectAvatar(String pathOrUrl) async {
    final session = context.read<SessionController>();
    await session.updateUser({'avatarUrl': pathOrUrl});
    if (mounted) {
      Navigator.pop(context);
      showSnack(
        context,
        context.read<LocaleController>().lang == 'ar'
            ? 'تم تحديث الصورة الشخصية بنجاح'
            : 'Photo de profil mise à jour avec succès',
      );
    }
  }

  void _pickFromDevice() {
    if (kIsWeb) {
      try {
        _jsOpenAvatarPicker('onAvatarPickedResult'.toJS);
      } catch (e) {
        showSnack(context, 'Importation de fichier: $e');
      }
    } else {
      showSnack(context, 'Disponible sur le navigateur');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    final isArabic = context.watch<LocaleController>().lang == 'ar';
    final currentAvatar = user.effectiveAvatar;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, color: AppColors.brand, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تغيير الصورة الشخصية' : 'Changer la photo de profil',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isArabic
                            ? 'اختر صورة من النماذج أو قم برفع صورتك'
                            : 'Choisissez un avatar de conducteur ou importez votre photo',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current photo preview
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brand, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: getUserAvatarProvider(currentAvatar),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Direct Photo Selection Actions
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                label: Text(
                  isArabic ? 'اختيار صورة من هاتفك أو جهازك' : 'Choisir une photo depuis mon appareil',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: _pickFromDevice,
              ),
            ),
            const SizedBox(height: 10),

            // Reset / Remove custom photo option
            if (currentAvatar.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(
                    isArabic ? 'حذف الصورة الشخصية واسترجاع الافتراضية' : 'Supprimer la photo et rétablir par défaut',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: () => _selectAvatar(''),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Paste URL Option
            TextButton.icon(
              icon: Icon(
                _showUrlField ? Icons.keyboard_arrow_up : Icons.link,
                size: 18,
              ),
              label: Text(
                isArabic ? 'أو لصق رابط صورة (URL)' : 'Ou coller le lien d\'une image (URL)',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => setState(() => _showUrlField = !_showUrlField),
            ),

            if (_showUrlField) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        hintText: 'https://exemple.com/photo.jpg',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final val = _urlController.text.trim();
                      if (val.isNotEmpty) {
                        _selectAvatar(val);
                      }
                    },
                    child: Text(isArabic ? 'تطبيق' : 'Appliquer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
