import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';
import 'package:hisaabchat/features/auth/presentation/password_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(fullName: _name.text, email: _email.text, password: _password.text);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _shake++;
        _fieldErrors = error.fieldErrors;
        _error = error.fieldErrors.isEmpty ? error.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      children: [
        Text('Create your account', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('It takes less than a minute.', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 28),
        Shake(
          trigger: _shake,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    prefixIcon: const Icon(AppIcons.name),
                    errorText: _fieldErrors['fullName'],
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(AppIcons.email),
                    errorText: _fieldErrors['email'] == null ? null : 'An account with this email already exists',
                  ),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  hint: 'Password (at least 8 characters)',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  errorText: _fieldErrors['password'],
                  validator: (value) {
                    if (value == null || value.length < 8) return 'Use at least 8 characters';
                    if (value.length > 64) return 'Use at most 64 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  hint: 'Confirm password',
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  validator: (value) => value != _password.text ? 'Passwords don’t match' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
        SubmitButton(label: 'Create account', loading: _loading, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pushReplacement('/login'),
          child: const Text('Already have an account? Log in'),
        ),
      ],
    );
  }
}
