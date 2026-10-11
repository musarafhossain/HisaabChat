import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:hisaabchat/features/auth/auth_controller.dart';
import 'package:hisaabchat/features/reports/data/report.dart';
import 'package:hisaabchat/features/reports/data/reports_repository.dart';
import 'package:hisaabchat/features/transactions/data/txn.dart';

/// Home dashboard for the current period.
final dashboardProvider = FutureProvider<Dashboard>((ref) async {
  ref.watch(authControllerProvider.select((auth) => auth.value?.id));
  return ref.watch(reportsRepositoryProvider).dashboard();
}, retry: (retryCount, error) => null);

typedef CategoryReportKey = ({TxnType type, String? month});

final FutureProviderFamily<CategoryReport, CategoryReportKey> categoryReportProvider =
    FutureProvider.family<CategoryReport, CategoryReportKey>(
      (ref, key) => ref.watch(reportsRepositoryProvider).byCategory(type: key.type, month: key.month),
      retry: (retryCount, error) => null,
    );

/// Six months of income and expense, ending with the given month (null = now).
final FutureProviderFamily<List<TrendPoint>, String?> trendProvider = FutureProvider.family<List<TrendPoint>, String?>(
  (ref, month) => ref.watch(reportsRepositoryProvider).trend(month: month),
  retry: (retryCount, error) => null,
);

/// Month shown on the Reports tab ("YYYY-MM"; null = current period).
class ReportMonth extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return null;
  }

  void show(String? month) => state = month;
}

final reportMonthProvider = NotifierProvider<ReportMonth, String?>(ReportMonth.new);

/// Forget cached report numbers (after any transaction or budget change).
void invalidateReports(Ref ref) {
  ref
    ..invalidate(dashboardProvider)
    ..invalidate(categoryReportProvider)
    ..invalidate(trendProvider);
}
