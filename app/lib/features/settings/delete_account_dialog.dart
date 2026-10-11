import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/presentation/password_field.dart';

/// The word to type before the Delete button wakes up.
const deleteConfirmWord = 'DELETE';

/// Settings → Delete account: type DELETE and the password, then everything
/// is erased on the server and this device signs out.
Future<void> showDeleteAccountDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog());

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  String? _passwordError;
  bool _busy = false;

  bool get _ready => _confirm.text.trim() == deleteConfirmWord && _password.text.isNotEmpty && !_busy;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
    _password.addListener(() => setState(() => _passwordError = null));
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_ready) return;
    setState(() => _busy = true);
    final toast = AppToast.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(_password.text);
      if (navigator.mounted && navigator.canPop()) navigator.pop();
      toast.show('Your account and all its data were deleted', kind: ToastKind.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _passwordError = error.fieldErrors['password'];
      });
      if (_passwordError == null) toast.show(error.message, kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This erases your accounts, transactions, budgets, people and recurring entries, and signs you out '
                'everywhere. It can’t be undone.',
              ),
              const SizedBox(height: 16),
              Text('Type $deleteConfirmWord to confirm', style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('delete-confirm'),
                controller: _confirm,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: deleteConfirmWord),
              ),
              const SizedBox(height: 12),
              PasswordField(
                key: const ValueKey('delete-password'),
                controller: _password,
                hint: 'Your password',
                errorText: _passwordError,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _delete(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _ready ? _delete : null,
          style: TextButton.styleFrom(foregroundColor: colors.danger),
          child: Text(_busy ? 'Deleting…' : 'Delete account'),
        ),
      ],
    );
  }
}
