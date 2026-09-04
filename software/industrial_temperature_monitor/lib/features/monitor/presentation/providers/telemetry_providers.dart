import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/telemetry_repository_impl.dart';
import '../../domain/entities/telemetry_entity.dart';
import '../../domain/repositories/telemetry_repository.dart';

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  return TelemetryRepositoryImpl();
});

// autoDispose: stops the RTDB subscription when no widget is watching it
// (e.g. after navigating away from the Telemetry tab), instead of leaving
// the socket open forever.
final telemetryStreamProvider = StreamProvider.autoDispose<TelemetryEntity>((
  ref,
) {
  final repo = ref.watch(telemetryRepositoryProvider);
  return repo.watchTelemetry();
});
