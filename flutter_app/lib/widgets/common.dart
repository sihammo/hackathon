import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../core/wilayas.dart';

// ---------------------------------------------------------------- formatting
String two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

String formatDate(DateTime d) => '${two(d.day)}/${two(d.month)}';

String formatDuration(Duration? d) {
  if (d == null) return '—';
  final s = d.inSeconds.abs();
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  if (m < 60) return '${m}min ${two(s % 60)}s';
  return '${m ~/ 60}h ${two(m % 60)}min';
}

/// Algerian numbers (05/06/07 mobiles, 0XX landlines, +213) or short codes.
bool isValidPhone(String v) {
  final t = v.replaceAll(RegExp(r'[\s\-.()]'), '');
  return RegExp(r'^(\+?\d{2,15})$').hasMatch(t);
}

// ---------------------------------------------------------------- widgets
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
          child: Icon(Icons.shield_outlined, color: Colors.white, size: size * 0.55),
        ),
      ),
    );
  }
}

/// Toggles between Arabic and French.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final lc = context.watch<LocaleController>();
    return TextButton.icon(
      onPressed: () => lc.setLanguage(lc.lang == 'ar' ? 'fr' : 'ar'),
      icon: const Icon(Icons.translate),
      label: Text(lc.lang == 'ar' ? 'Français' : 'العربية'),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String text;
  const ErrorBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: cs.onErrorContainer))),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline, this.color = AppColors.warn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class WilayaDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final FormFieldValidator<int>? validator;
  final String? label;

  const WilayaDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.validator,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return DropdownButtonFormField<int>(
      // Rebuild the field when the value changes from outside.
      key: ValueKey('wilaya-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label ?? context.tr('wilaya'),
        prefixIcon: const Icon(Icons.location_city_outlined),
      ),
      items: [
        for (final w in Wilayas.all)
          DropdownMenuItem(value: w.code, child: Text(w.label(lang), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Text(
        context.tr('status_$status'),
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;

  const SectionCard({super.key, this.title, this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title!,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const InfoRow(this.label, this.value, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: muted), const SizedBox(width: 8)],
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.tr('confirm'))),
      ],
    ),
  );
  return r == true;
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
