import 'package:flutter/material.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/motion/animated_icons.dart';

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.hint,
    super.key,
    this.validator,
    this.errorText,
    this.autofillHints,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: const Icon(AppIcons.password),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: MorphIcon(first: AppIcons.showPassword, second: AppIcons.hidePassword, showSecond: !_obscure),
        ),
      ),
    );
  }
}
