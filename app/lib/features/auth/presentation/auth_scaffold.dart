import 'package:flutter/material.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';

/// Full screen on phones; a centered column (max 420 dp) on wide screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.children, super.key, this.showBack = true});

  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack
          ? AppBar(
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red inline message shown above the submit button.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.failed, color: colors.danger, fill: 1, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Green pill button with an inline spinner while [loading].
class SubmitButton extends StatelessWidget {
  const SubmitButton({required this.label, required this.loading, required this.onPressed, super.key});

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: loading
            ? SizedBox.square(
                key: const ValueKey('spinner'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Theme.of(context).colorScheme.onPrimary),
              )
            : Text(label, key: const ValueKey('label')),
      ),
    );
  }
}

/// Simple email shape check; the server is the source of truth.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email';
  return null;
}
