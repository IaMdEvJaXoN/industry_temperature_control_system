import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:industrial_temperature_monitor/features/monitor/domain/entities/config_entity.dart';
import 'package:industrial_temperature_monitor/features/monitor/domain/entities/telemetry_entity.dart';
import 'package:industrial_temperature_monitor/features/monitor/domain/repositories/telemetry_repository.dart';
import 'package:industrial_temperature_monitor/features/monitor/data/models/config_model.dart';
import 'package:industrial_temperature_monitor/features/monitor/data/models/telemetry_model.dart';
import 'package:industrial_temperature_monitor/core/constants/app_constants.dart';

class TelemetryRepositoryImpl implements TelemetryRepository {
  final DatabaseReference _telemetryRef;
  final DatabaseReference _configRef;

  TelemetryRepositoryImpl()
    : _telemetryRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: RtdbPaths.databaseUrl,
      ).ref(RtdbPaths.telemetryRoot),
      _configRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: RtdbPaths.databaseUrl,
      ).ref(RtdbPaths.configRoot);

  @override
  Stream<TelemetryEntity> watchTelemetry() {
    return _telemetryRef.onValue.map((DatabaseEvent event) {
      try {
        return TelemetryModel.fromRtdb(event.snapshot.value).toEntity();
      } catch (_) {
        return TelemetryEntity.empty();
      }
    });
  }

  double _parseLeafDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? double.nan;
    return double.nan;
  }

  @override
  Stream<double> watchProcessTemp() {
    return _telemetryRef.child('processTemp').onValue.map((event) {
      return _parseLeafDouble(event.snapshot.value);
    });
  }

  @override
  Stream<double> watchPcbTemp() {
    return _telemetryRef.child('pcbTemp').onValue.map((event) {
      return _parseLeafDouble(event.snapshot.value);
    });
  }

  @override
  Stream<ConfigEntity> watchConfig() {
    return _configRef.onValue.map((DatabaseEvent event) {
      try {
        return ConfigModel.fromRtdb(event.snapshot.value).toEntity();
      } catch (_) {
        return ConfigEntity.empty();
      }
    });
  }

  @override
  Future<void> pushConfig(ConfigEntity config) async {
    if (!config.isValid) {
      throw ArgumentError('Invalid config: requires min < target < max');
    }
    await _configRef.set(ConfigModel.fromEntity(config).toRtdbPayload());
  }
}
