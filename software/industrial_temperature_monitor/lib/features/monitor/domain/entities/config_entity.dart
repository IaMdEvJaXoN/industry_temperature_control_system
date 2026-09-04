class ConfigEntity {
  final double target;
  final double max;
  final double min;

  const ConfigEntity({
    required this.target,
    required this.max,
    required this.min,
  });

  factory ConfigEntity.empty() => const ConfigEntity(target: 0, max: 0, min: 0);

  bool get isValid => min < target && target < max;
}
