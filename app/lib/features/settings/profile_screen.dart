import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/config/device.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/auth/data/app_user.dart';
import 'package:hisaabchat/features/auth/presentation/auth_scaffold.dart';

/// Common IANA zones offered in the picker; the device zone is added on top.
const _commonTimezones = [
  'Asia/Kolkata',
  'Asia/Dhaka',
  'Asia/Kathmandu',
  'Asia/Colombo',
  'Asia/Karachi',
  'Asia/Dubai',
  'Asia/Riyadh',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Europe/London',
  'Europe/Berlin',
  'America/New_York',
  'America/Chicago',
  'America/Los_Angeles',
  'Australia/Sydney',
  'UTC',
];

/// Account settings: name, time zone, month start day (PATCH /me).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AppUser _initial = ref.read(authControllerProvider).value!;
  late final _name = TextEditingController(text: _initial.fullName ?? '');
  late String _timezone = _initial.timezone;
  late int _monthStartDay = _initial.monthStartDay;
  String? _deviceTimezone;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Device.timezone().then((zone) {
      if (mounted) setState(() => _deviceTimezone = zone);
    }).ignore();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _name.text.trim() != (_initial.fullName ?? '') ||
      _timezone != _initial.timezone ||
      _monthStartDay != _initial.monthStartDay;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'fullName': _name.text.trim(),
        'timezone': _timezone,
        'monthStartDay': _monthStartDay,
      });
      if (!mounted) return;
      AppToast.success(context, 'Profile saved');
      unawaited(Navigator.of(context).maybePop());
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.fieldErrors.values.firstOrNull ?? error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final zones = {?_deviceTimezone, _initial.timezone, ..._commonTimezones}.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Your name', prefixIcon: Icon(AppIcons.name)),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SectionLabel('Time zone'),
                DropdownButtonFormField<String>(
                  initialValue: _timezone,
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(AppIcons.timezone)),
                  items: [
                    for (final zone in zones)
                      DropdownMenuItem(
                        value: zone,
                        child: Text(zone == _deviceTimezone ? '$zone  (this device)' : zone),
                      ),
                  ],
                  onChanged: (zone) => setState(() => _timezone = zone ?? _timezone),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    'Used to decide which day and month each transaction belongs to.',
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                ),
                const SectionLabel('Month starts on'),
                DropdownButtonFormField<int>(
                  initialValue: _monthStartDay,
                  decoration: const InputDecoration(prefixIcon: Icon(AppIcons.monthStart)),
                  items: [
                    for (var day = 1; day <= 28; day++)
                      DropdownMenuItem(value: day, child: Text(day == 1 ? '1st (calendar month)' : _ordinal(day))),
                  ],
                  onChanged: (day) => setState(() => _monthStartDay = day ?? _monthStartDay),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    'Paid on the 25th? Start your budget month on the 25th.',
                    style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                  ),
                ),
                const SectionLabel('Currency'),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(AppIcons.currency),
                  title: Text('Indian Rupee (₹)'),
                  subtitle: Text('More currencies are planned for a later version'),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[FormErrorBanner(_error!), const SizedBox(height: 16)],
                SubmitButton(label: 'Save', loading: _saving, onPressed: _dirty ? _save : () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}
