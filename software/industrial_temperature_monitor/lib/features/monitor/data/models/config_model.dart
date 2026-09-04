import 'package:industrial_temperature_monitor/features/monitor/domain/entities/config_entity.dart';

class ConfigModel {
  final double target;
  final double max;
  final double min;

  const ConfigModel({
    required this.target,
    required this.max,
    required this.min,
  });

  factory ConfigModel.fromRtdb(Object? json) {
    if (json is! Map) return const ConfigModel(target: 0, max: 0, min: 0);

    double parse(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return ConfigModel(
      target: parse(json['target']),
      max: parse(json['max']),
      min: parse(json['min']),
    );
  }

  factory ConfigModel.fromEntity(ConfigEntity e) {
    return ConfigModel(target: e.target, max: e.max, min: e.min);
  }

  ConfigEntity toEntity() => ConfigEntity(target: target, max: max, min: min);

  Map<String, Object> toRtdbPayload() {
    return {'target': target, 'max': max, 'min': min};
  }
}
