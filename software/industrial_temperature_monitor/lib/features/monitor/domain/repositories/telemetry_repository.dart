import 'package:industrial_temperature_monitor/features/monitor/domain/entities/telemetry_entity.dart';
import 'package:industrial_temperature_monitor/features/monitor/domain/entities/config_entity.dart';

abstract class TelemetryRepository {
  Stream<TelemetryEntity> watchTelemetry();
  Stream<double> watchProcessTemp();
  Stream<double> watchPcbTemp();
  Stream<ConfigEntity> watchConfig();
  Future<void> pushConfig(ConfigEntity config);
}

abstract class HistoryRepository {
  Future<void> appendProcessLog(String rawEntry);
  Future<void> appendPcbLog(String rawEntry);
  Stream<List<String>> watchProcessLog();
  Stream<List<String>> watchPcbLog();
}
