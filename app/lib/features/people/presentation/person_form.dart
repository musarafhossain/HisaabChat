import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/shake.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/adaptive_sheet.dart';
import 'package:hisaabchat/features/people/data/person.dart';
import 'package:hisaabchat/features/people/people_controller.dart';

/// Add or rename someone you lend to or borrow from.
Future<Person?> showPersonForm(BuildContext context, {Person? existing}) =>
    showAdaptiveSheet<Person>(context, child: PersonForm(existing: existing), maxDialogWidth: 440);

class PersonForm extends ConsumerStatefulWidget {
  const PersonForm({super.key, this.existing});

  final Person? existing;

  @override
  ConsumerState<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends ConsumerState<PersonForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};
  int _shake = 0;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _shake++);
      return;
    }
    final phone = _phone.text.trim();
    final body = <String, Object?>{'name': _name.text.trim(), 'phone': phone.isEmpty ? null : phone};

    setState(() => _saving = true);
    final controller = ref.read(peopleProvider.notifier);
    try {
      final saved = _isEdit ? await controller.updatePerson(widget.existing!.id, body) : await controller.create(body);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _shake++;
        _fieldErrors = error.fieldErrors;
        _error = error.fieldErrors.isEmpty ? error.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Shake(
        trigger: _shake,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? 'Edit person' : 'New person',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Track money you lend to or borrow from them. Each person gets their own chat.',
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(AppIcons.person),
                  errorText: _fieldErrors['name'],
                  counterText: '',
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(AppIcons.phone),
                  counterText: '',
                ),
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: colors.danger)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Save' : 'Add person'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
