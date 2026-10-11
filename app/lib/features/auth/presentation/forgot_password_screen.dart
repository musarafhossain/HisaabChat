import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/data/auth_repository.dart';
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';
import 'package:hisaabchat/features/auth/presentation/password_field.dart';

/// "Forgot password": email → 6-digit code by email → new password. Then
/// signs in with the new password (the router takes over from there).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Set once a code has been sent (step 2).
  String? _sentTo;
  bool _loading = false;
  bool _resending = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _fail(ApiException error) {
    setState(() {
      _loading = false;
      _resending = false;
      _shake++;
      _fieldErrors = error.fieldErrors;
      _error = error.fieldErrors.isEmpty ? error.message : null;
    });
  }

  Future<void> _sendCode({bool resend = false}) async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!resend && !_emailForm.currentState!.validate()) return;
    setState(() => resend ? _resending = true : _loading = true);
    final toast = AppToast.of(context);
    try {
      final email = _email.text.trim();
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _sentTo = email;
        _loading = false;
        _resending = false;
      });
      if (resend) toast.show('Sent a new code to $email', kind: ToastKind.success);
    } on ApiException catch (error) {
      if (mounted) _fail(error);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_resetForm.currentState!.validate()) return;
    setState(() => _loading = true);
    final toast = AppToast.of(context);
    final email = _sentTo!;
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(email: email, code: _code.text.trim(), password: _password.text);
      // Sign straight in with the new password; the router opens the app.
      await ref.read(authControllerProvider.notifier).login(email: email, password: _password.text);
      toast.show('Password changed. You’re signed in.', kind: ToastKind.success);
    } on ApiException catch (error) {
      if (mounted) _fail(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentTo = _sentTo;
    final errorBanner = _error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shake(trigger: _shake, child: FormErrorBanner(_error!)),
          );

    if (sentTo == null) {
      return AuthScaffold(
        children: [
          Text('Forgot password', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Enter your email and we’ll send you a 6-digit code.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 28),
          Form(
            key: _emailForm,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                hintText: 'Email',
                prefixIcon: const Icon(AppIcons.email),
                errorText: _fieldErrors['email'],
              ),
              validator: validateEmail,
              onFieldSubmitted: (_) => _sendCode(),
            ),
          ),
          const SizedBox(height: 20),
          errorBanner,
          SubmitButton(label: 'Send code', loading: _loading, onPressed: _sendCode),
        ],
      );
    }

    return AuthScaffold(
      children: [
        Text('Check your email', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'If $sentTo has an account, we sent it a 6-digit code. It works for 15 minutes.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 28),
        AutofillGroup(
          child: Form(
            key: _resetForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('reset-code'),
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '6-digit code',
                    hintStyle: TextStyle(fontSize: 16, letterSpacing: 0, color: context.colors.textSecondary),
                    prefixIcon: const Icon(AppIcons.password),
                    errorText: _fieldErrors['code'],
                  ),
                  validator: (value) => (value ?? '').length == 6 ? null : 'Enter the 6 digits from the email',
                ),
                const SizedBox(height: 14),
                PasswordField(
                  key: const ValueKey('reset-password'),
                  controller: _password,
                  hint: 'New password (at least 8 characters)',
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
                  key: const ValueKey('reset-confirm'),
                  controller: _confirm,
                  hint: 'Confirm new password',
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _reset(),
                  validator: (value) => value != _password.text ? 'Passwords don’t match' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        errorBanner,
        SubmitButton(label: 'Change password', loading: _loading, onPressed: _reset),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: _resending || _loading ? null : () => _sendCode(resend: true),
              child: Text(_resending ? 'Sending…' : 'Send a new code'),
            ),
            TextButton(
              onPressed: _loading ? null : () => setState(() => _sentTo = null),
              child: const Text('Use another email'),
            ),
          ],
        ),
      ],
    );
  }
}
