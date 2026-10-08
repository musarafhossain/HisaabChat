import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';
import 'package:hisaabchat/features/auth/presentation/password_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      await ref.read(authControllerProvider.notifier).login(email: _email.text, password: _password.text);
      // The router redirects to the app once the session is set.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _shake++;
        _fieldErrors = error.fieldErrors;
        _error = error.statusCode == 400 ? 'Incorrect email or password' : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      children: [
        Text('Log in', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Welcome back. Your accounts are waiting.', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 28),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(AppIcons.email),
                  errorText: _fieldErrors['email'],
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                hint: 'Password',
                autofillHints: const [AutofillHints.password],
                errorText: _fieldErrors['password'],
                onSubmitted: (_) => _submit(),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Shake(trigger: _shake, child: FormErrorBanner(_error!)),
          const SizedBox(height: 16),
        ],
        SubmitButton(label: 'Log in', loading: _loading, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.pushReplacement('/register'),
          child: const Text('New here? Create an account'),
        ),
      ],
    );
  }
}
