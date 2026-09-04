import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:industrial_temperature_monitor/features/monitor/data/repositories/history_repository_impl.dart';
import 'package:industrial_temperature_monitor/features/monitor/domain/repositories/telemetry_repository.dart';
import 'telemetry_providers.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepositoryImpl();
});

final processHistoryProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(historyRepositoryProvider).watchProcessLog();
});

final pcbHistoryProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return ref.watch(historyRepositoryProvider).watchPcbLog();
});

final processTempStreamProvider = StreamProvider.autoDispose<double>((ref) {
  final repo = ref.watch(telemetryRepositoryProvider);
  return repo.watchProcessTemp();
});

final pcbTempStreamProvider = StreamProvider.autoDispose<double>((ref) {
  final repo = ref.watch(telemetryRepositoryProvider);
  return repo.watchPcbTemp();
});

final historyDispatcherProvider = Provider<void>((ref) {
  final repo = ref.read(historyRepositoryProvider);

  ref.listen<AsyncValue<double>>(processTempStreamProvider, (previous, next) {
    next.whenData((value) {
      if (value.isNaN) return;
      repo.appendProcessLog('${value.toStringAsFixed(2)}°C');
    });
  });

  ref.listen<AsyncValue<double>>(pcbTempStreamProvider, (previous, next) {
    next.whenData((value) {
      if (value.isNaN) return;
      repo.appendPcbLog('${value.toStringAsFixed(2)}°C');
    });
  });
});
