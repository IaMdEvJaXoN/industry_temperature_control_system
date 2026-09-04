import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:industrial_temperature_monitor/core/theme/app_theme.dart';
import 'package:industrial_temperature_monitor/core/theme/app_card.dart';
import 'package:industrial_temperature_monitor/features/monitor/domain/entities/telemetry_entity.dart';
import 'package:industrial_temperature_monitor/features/monitor/presentation/providers/telemetry_providers.dart';
import 'package:industrial_temperature_monitor/features/monitor/presentation/widgets/actuation_indicator.dart';

class TelemetryScreen extends ConsumerWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(telemetryStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('TELEMETRY')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: telemetryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            ),
          ),
          error: (err, st) => Text(
            'Telemetry stream error: $err',
            style: const TextStyle(color: AppColors.alarmCritical),
          ),
          data: (t) => _TelemetryBody(telemetry: t),
        ),
      ),
    );
  }
}

class _TelemetryBody extends StatelessWidget {
  final TelemetryEntity telemetry;
  const _TelemetryBody({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              ActuationIndicator(state: telemetry.actuationState),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      telemetry.actuationState.isEmpty
                          ? 'UNKNOWN'
                          : telemetry.actuationState,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      telemetry.pcbCoolingState.isEmpty
                          ? 'PCB status unknown'
                          : telemetry.pcbCoolingState,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TempCard(
                label: 'PROCESS TEMP',
                value: telemetry.processTemp,
                icon: Icons.device_thermostat,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TempCard(
                label: 'PCB TEMP',
                value: telemetry.pcbTemp,
                icon: Icons.memory,
                color: AppColors.accentSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              const Icon(
                Icons.update,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Last update: ${_formatTime(telemetry.receivedAt)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) {
    if (t.millisecondsSinceEpoch == 0) return 'never';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _TempCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _TempCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value.isNaN ? '--.-°C' : '${value.toStringAsFixed(1)}°C',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
