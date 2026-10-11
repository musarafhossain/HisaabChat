import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/widgets/settings_tile.dart';
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/export/export_actions.dart';
import 'package:intl/intl.dart';

/// The ranges offered for the CSV export.
enum ExportRange {
  thisMonth('This month'),
  lastMonth('Last month'),
  thisYear('This year'),
  allTime('All time'),
  custom('Custom')
  ;

  const ExportRange(this.label);
  final String label;
}

/// First and last day (both included) of a range; null ends mean "no limit".
/// Months follow the user's month start day (e.g. 5 → 5 Oct – 4 Nov).
({DateTime? from, DateTime? to}) exportRangeDates(ExportRange range, {required DateTime today, int monthStartDay = 1}) {
  DateTime periodStart(int monthsBack) {
    final startsThisMonth = today.day >= monthStartDay;
    return DateTime(today.year, today.month - (startsThisMonth ? 0 : 1) - monthsBack, monthStartDay);
  }

  DateTime dayBefore(DateTime day) => DateTime(day.year, day.month, day.day - 1);
  final current = periodStart(0);

  return switch (range) {
    ExportRange.thisMonth => (
      from: current,
      to: dayBefore(DateTime(current.year, current.month + 1, monthStartDay)),
    ),
    ExportRange.lastMonth => (from: periodStart(1), to: dayBefore(current)),
    ExportRange.thisYear => (from: DateTime(today.year), to: DateTime(today.year, 12, 31)),
    ExportRange.allTime || ExportRange.custom => (from: null, to: null),
  };
}

/// Settings → Export data: transactions as CSV (for spreadsheets) and a
/// full JSON backup.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportRange _range = ExportRange.thisMonth;
  DateTimeRange? _custom;
  bool _busyCsv = false;
  bool _busyJson = false;

  static final _date = DateFormat('d MMM y');

  ({DateTime? from, DateTime? to}) get _dates {
    if (_range == ExportRange.custom) return (from: _custom?.start, to: _custom?.end);
    final user = ref.read(authControllerProvider).value;
    return exportRangeDates(_range, today: DateTime.now(), monthStartDay: user?.monthStartDay ?? 1);
  }

  /// Android hands files to the share sheet; elsewhere they're saved.
  bool get _shares => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
      helpText: 'Export transactions from',
    );
    if (picked != null) setState(() => _custom = picked);
  }

  Future<void> _select(ExportRange range) async {
    setState(() => _range = range);
    if (range == ExportRange.custom && _custom == null) await _pickCustom();
  }

  Future<void> _exportCsv() async {
    final dates = _dates;
    setState(() => _busyCsv = true);
    await runExport(context, ref, (repo) => repo.transactionsCsv(from: dates.from, to: dates.to));
    if (mounted) setState(() => _busyCsv = false);
  }

  Future<void> _exportJson() async {
    setState(() => _busyJson = true);
    await runExport(context, ref, (repo) => repo.backupJson());
    if (mounted) setState(() => _busyJson = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hint = TextStyle(fontSize: 12.5, color: colors.textSecondary);
    final dates = _dates;
    final rangeText = switch (dates) {
      (from: final DateTime f, to: final DateTime t) => '${_date.format(f)} – ${_date.format(t)}',
      _ when _range == ExportRange.custom => 'Pick the dates',
      _ => 'Every transaction you’ve added',
    };
    const spinner = SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export data', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const SectionLabel('Transactions (CSV)'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final range in ExportRange.values)
                      ChoiceChip(
                        label: Text(range.label),
                        selected: _range == range,
                        onSelected: (_) => _select(range),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(AppIcons.month),
                title: Text(rangeText),
                trailing: _range == ExportRange.custom
                    ? TextButton(onPressed: _pickCustom, child: const Text('Change'))
                    : null,
                onTap: _range == ExportRange.custom ? _pickCustom : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'One row per transaction with date, type, amount, account, category, person and note. '
                  'Opens in Excel or Google Sheets.',
                  style: hint,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _busyCsv || (_range == ExportRange.custom && _custom == null) ? null : _exportCsv,
                    icon: _busyCsv ? spinner : Icon(_shares ? AppIcons.share : AppIcons.download),
                    label: Text(_busyCsv ? 'Preparing…' : 'Export CSV'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SectionLabel('Full backup (JSON)'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Everything in one file: accounts, categories, budgets, people, transactions and recurring '
                  'entries. Amounts are in paise. Keep it somewhere safe.',
                  style: hint,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busyJson ? null : _exportJson,
                    icon: _busyJson ? spinner : const Icon(AppIcons.data),
                    label: Text(_busyJson ? 'Preparing…' : 'Export backup'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
