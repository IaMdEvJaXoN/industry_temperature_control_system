import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:industrial_temperature_monitor/features/monitor/domain/entities/config_entity.dart';
import 'telemetry_providers.dart';

final configStreamProvider = StreamProvider.autoDispose<ConfigEntity>((ref) {
  final repo = ref.watch(telemetryRepositoryProvider);
  return repo.watchConfig();
});

// Manual AsyncNotifier. Holds a local draft so in-progress edits aren't
// clobbered by a live RTDB value changing mid-edit; only pushed to RTDB
// when save() is called explicitly.
class ConfigEditNotifier extends AsyncNotifier<ConfigEntity> {
  @override
  Future<ConfigEntity> build() async {
    final repo = ref.watch(telemetryRepositoryProvider);
    return repo.watchConfig().first;
  }

  void updateDraft(ConfigEntity draft) {
    state = AsyncValue.data(draft);
  }

  Future<void> save() async {
    final draft = state.value;
    if (draft == null) return;
    if (!draft.isValid) {
      throw ArgumentError('Config invalid: requires min < target < max');
    }
    final repo = ref.read(telemetryRepositoryProvider);
    try {
      await repo.pushConfig(draft);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final configEditProvider =
    AsyncNotifierProvider<ConfigEditNotifier, ConfigEntity>(
      ConfigEditNotifier.new,
    );
