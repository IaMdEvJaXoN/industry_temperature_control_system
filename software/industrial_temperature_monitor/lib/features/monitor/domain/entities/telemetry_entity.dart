class TelemetryEntity {
  final double processTemp;
  final double pcbTemp;
  final String actuationState;
  final String pcbCoolingState;
  final DateTime receivedAt;

  const TelemetryEntity({
    required this.processTemp,
    required this.pcbTemp,
    required this.actuationState,
    required this.pcbCoolingState,
    required this.receivedAt,
  });

  factory TelemetryEntity.empty() {
    return TelemetryEntity(
      processTemp: double.nan,
      pcbTemp: double.nan,
      actuationState: '',
      pcbCoolingState: '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
