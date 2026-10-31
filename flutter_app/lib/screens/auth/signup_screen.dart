import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../services/auth.dart';
import '../../widgets/common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _phone = TextEditingController();
  int? _wilaya;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fullName, _username, _password, _confirm, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await context.read<SessionController>().signUp(
            fullName: _fullName.text,
            username: _username.text,
            password: _password.text,
            phone: _phone.text,
            wilayaCode: _wilaya!,
          );
      // The AuthGate switches to the home screen; close this page.
      if (mounted) nav.popUntil((r) => r.isFirst);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.key);
    } catch (_) {
      if (mounted) setState(() => _error = 'err_generic');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? context.tr('err_required') : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(context.tr('create_account')),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullName,
                      decoration: InputDecoration(
                        labelText: context.tr('full_name'),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: required,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _username,
                      decoration: InputDecoration(
                        labelText: context.tr('username'),
                        helperText: context.tr('username_hint'),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      autocorrect: false,
                      validator: (v) {
                        if (required(v) != null) return required(v);
                        if (!AuthService.usernameRegex.hasMatch(AuthService.normalize(v!))) {
                          return context.tr('err_username_format');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: context.tr('password'),
                        helperText: context.tr('password_hint'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? context.tr('err_weak_password') : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: context.tr('password_confirm'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) =>
                          v != _password.text ? context.tr('err_password_mismatch') : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: context.tr('phone'),
                        hintText: '0550 12 34 56',
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (required(v) != null) return required(v);
                        return isValidPhone(v!) ? null : context.tr('err_phone');
                      },
                    ),
                    const SizedBox(height: 16),
                    WilayaDropdown(
                      value: _wilaya,
                      onChanged: (v) => setState(() => _wilaya = v),
                      validator: (v) => v == null ? context.tr('err_required') : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(context.tr(_error!)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(context.tr('create_account')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
