import 'package:industrial_temperature_monitor/features/monitor/domain/entities/telemetry_entity.dart';

class TelemetryModel {
  final double processTemp;
  final double pcbTemp;
  final String actuationState;
  final String pcbCoolingState;

  const TelemetryModel({
    required this.processTemp,
    required this.pcbTemp,
    required this.actuationState,
    required this.pcbCoolingState,
  });

  factory TelemetryModel.fromRtdb(Object? json) {
    if (json is! Map) {
      return const TelemetryModel(
        processTemp: double.nan,
        pcbTemp: double.nan,
        actuationState: '',
        pcbCoolingState: '',
      );
    }

    double parseTemp(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? double.nan;
      return double.nan;
    }

    return TelemetryModel(
      processTemp: parseTemp(json['processTemp']),
      pcbTemp: parseTemp(json['pcbTemp']),
      actuationState: json['actuationState']?.toString() ?? '',
      pcbCoolingState: json['pcbCoolingState']?.toString() ?? '',
    );
  }

  TelemetryEntity toEntity() {
    return TelemetryEntity(
      processTemp: processTemp,
      pcbTemp: pcbTemp,
      actuationState: actuationState,
      pcbCoolingState: pcbCoolingState,
      receivedAt: DateTime.now(),
    );
  }
}
