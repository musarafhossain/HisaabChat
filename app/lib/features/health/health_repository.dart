import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_client.dart';

@immutable
class HealthStatus {
  const HealthStatus({required this.status, required this.database, required this.serverTime});

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    status: json['status'] as String,
    database: json['database'] as String,
    serverTime: DateTime.parse(json['time'] as String),
  );

  final String status;
  final String database;
  final DateTime serverTime;

  bool get isHealthy => status == 'ok' && database == 'up';
}

final FutureProvider<HealthStatus> healthProvider = FutureProvider.autoDispose<HealthStatus>(
  (ref) async {
    final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/health');
    return HealthStatus.fromJson(json);
  },
  // A connection check should report failures immediately instead of
  // silently retrying in the background; the user can tap "Try again".
  retry: (retryCount, error) => null,
);
