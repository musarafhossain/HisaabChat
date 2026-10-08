import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaabchat/app/theme/app_colors.dart';
import 'package:hisaabchat/core/icons/app_icons.dart';
import 'package:hisaabchat/core/money/money.dart';
import 'package:hisaabchat/core/motion/entrance.dart';
import 'package:hisaabchat/core/motion/motion.dart';
import 'package:hisaabchat/core/widgets/chat_tile.dart';
import 'package:hisaabchat/core/widgets/empty_state.dart';
import 'package:hisaabchat/core/widgets/offline_banner.dart';
import 'package:hisaabchat/core/widgets/search_pill.dart';
import 'package:hisaabchat/core/widgets/skeleton.dart';
import 'package:hisaabchat/features/budgets/presentation/budgets_section.dart' show periodLabel, shiftMonth;
import 'package:hisaabchat/features/reports/data/report.dart';
import 'package:hisaabchat/features/reports/reports_controller.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';
import 'package:intl/intl.dart';

/// Reports tab: where the money went (donut + ranked categories, tap one to
/// see its transactions) and six months of money in vs out.
class ReportsSection extends ConsumerStatefulWidget {
  const ReportsSection({super.key});

  @override
  ConsumerState<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends ConsumerState<ReportsSection> {
  TxnType _type = TxnType.expense;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(reportMonthProvider);
    final key = (type: _type, month: month);
    final report = ref.watch(categoryReportProvider(key));
    final trend = ref.watch(trendProvider(month));
    final data = report.value;
    final colors = context.colors;
    final error = report.error ?? trend.error;

    final breakdown = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterChipsRow(
          labels: const ['Spending', 'Income'],
          selected: _type == TxnType.expense ? 0 : 1,
          onSelected: (i) => setState(() => _type = i == 0 ? TxnType.expense : TxnType.income),
        ),
        if (data == null && report.isLoading)
          const _BreakdownSkeleton()
        else if (data != null && data.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: EmptyState(
              icon: AppIcons.pieChart,
              title: _type == TxnType.expense ? 'No spending this month' : 'No income this month',
              message: 'Transactions you add show up here by category.',
            ),
          )
        else if (data != null) ...[
          FadeSlideIn(child: _Donut(report: data)),
          for (final (i, item) in data.items.indexed)
            FadeSlideIn(
              index: 1 + i,
              child: _CategoryRow(item: item, onTap: () => _openCategory(data, item)),
            ),
        ],
      ],
    );

    final trendCard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(
            'Money in vs out · last 6 months',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textSecondary),
          ),
        ),
        if (trend.value case final points?)
          FadeSlideIn(index: 2, child: _TrendChart(points: points))
        else if (trend.isLoading)
          const Padding(padding: EdgeInsets.all(16), child: Skeleton(height: 180, radius: 16)),
      ],
    );

    return Column(
      children: [
        if (error != null && !report.isLoading && !trend.isLoading)
          OfflineBanner(
            error: error,
            onRetry: () => ref
              ..invalidate(categoryReportProvider(key))
              ..invalidate(trendProvider(month)),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _MonthSwitcher(report: data),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: colors.primary,
            onRefresh: () async {
              ref.invalidate(trendProvider(month));
              try {
                final _ = await ref.refresh(categoryReportProvider(key).future);
              } on Object {
                // The offline banner shows the error.
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? 1100 : 720),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: breakdown),
                                  Expanded(child: trendCard),
                                ],
                              )
                            : Column(children: [breakdown, trendCard]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openCategory(CategoryReport report, CategorySpend item) {
    final uri = Uri(
      path: '/reports/category/${item.categoryId}',
      queryParameters: {
        'name': item.name,
        'from': report.from.toUtc().toIso8601String(),
        'to': report.to.toUtc().toIso8601String(),
        'period': periodLabel(report.periodStart, report.periodEnd),
      },
    );
    unawaited(context.push(uri.toString()));
  }
}

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher({required this.report});

  final CategoryReport? report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reportMonthProvider.notifier);
    final current = ref.watch(reportMonthProvider) == null;
    final report = this.report;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(AppIcons.back),
            onPressed: report == null ? null : () => notifier.show(shiftMonth(report.month, -1)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  report == null ? ' ' : periodLabel(report.periodStart, report.periodEnd),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
                ),
                if (!current)
                  TextButton(
                    onPressed: () => notifier.show(null),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Back to this month'),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(AppIcons.forward),
            onPressed: report == null ? null : () => notifier.show(shiftMonth(report.month, 1)),
          ),
        ],
      ),
    );
  }
}

/// Donut of the largest categories (the rest grouped as "Other").
class _Donut extends StatelessWidget {
  const _Donut({required this.report});

  final CategoryReport report;

  static const _maxSlices = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = report.items;
    final top = items.take(_maxSlices).toList();
    final other = items.skip(_maxSlices).fold<int>(0, (sum, i) => sum + i.total);
    final slices = [for (final item in top) (item.total, item.color), if (other > 0) (other, colors.textSecondary)];

    return Semantics(
      label:
          '${report.type == TxnType.expense ? 'Spent' : 'Received'} ${Money.format(report.total)}. '
          '${top.map((i) => '${i.name} ${i.percent.round()} percent').join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 2,
                centerSpaceRadius: 70,
                pieTouchData: PieTouchData(enabled: false),
                sections: [
                  for (final (value, color) in slices)
                    PieChartSectionData(value: value.toDouble(), color: color, radius: 26, showTitle: false),
                ],
              ),
              duration: context.motion(const Duration(milliseconds: 500)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  report.type == TxnType.expense ? 'Spent' : 'Received',
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 124),
                  child: FittedBox(
                    child: Text(
                      Money.format(report.total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                Text(
                  '${report.items.length} ${report.items.length == 1 ? 'category' : 'categories'}',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ranked row: icon, name, share bar, amount and percent.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item, required this.onTap});

  final CategorySpend item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChatTile(
      onTap: onTap,
      leading: IconAvatar(icon: AppIcons.byKey(item.icon), color: item.color),
      title: item.name,
      subtitleWidget: Padding(
        padding: const EdgeInsets.only(top: 6, right: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: item.percent / 100),
            duration: context.motion(const Duration(milliseconds: 500)),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                LinearProgressIndicator(value: value, minHeight: 6, color: item.color, backgroundColor: colors.divider),
          ),
        ),
      ),
      trailing: Text(
        Money.format(item.total),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
      ),
      trailingCaption: _percent(item.percent),
    );
  }

  static String _percent(double value) =>
      value == value.roundToDouble() ? '${value.round()}%' : '${value.toStringAsFixed(1)}%';
}

class _BreakdownSkeleton extends StatelessWidget {
  const _BreakdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Skeleton.circle(size: 192),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) const SkeletonTile(),
      ],
    );
  }
}

/// Grouped bars: money in (green) and out (red) per month.
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = points.fold<int>(0, (m, p) => math.max(m, math.max(p.income, p.expense)));

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
      ],
    );

    return Semantics(
      label:
          'Money in and out for the last six months: '
          '${points.map((p) => '${_monthName(p.month)}: in ${Money.format(p.income)}, out ${Money.format(p.expense)}').join('; ')}',
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    maxY: maxY == 0 ? 1 : maxY / 100 * 1.15,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => colors.toastBackground,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final point = points[group.x];
                          return BarTooltipItem(
                            '${rodIndex == 0 ? 'In' : 'Out'} '
                            '${Money.format(rodIndex == 0 ? point.income : point.expense)}',
                            TextStyle(color: colors.onToast, fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            meta: meta,
                            child: Text(
                              _monthName(points[value.toInt()].month),
                              style: TextStyle(fontSize: 12, color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    barGroups: [
                      for (final (i, point) in points.indexed)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            BarChartRodData(
                              toY: point.income / 100,
                              width: 10,
                              color: colors.income,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: point.expense / 100,
                              width: 10,
                              color: colors.expense,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: context.motion(const Duration(milliseconds: 400)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 16, children: [legend(colors.income, 'Money in'), legend(colors.expense, 'Money out')]),
            ],
          ),
        ),
      ),
    );
  }

  static String _monthName(String month) {
    final parts = month.split('-').map(int.parse).toList();
    return DateFormat('MMM').format(DateTime(parts[0], parts[1]));
  }
}
