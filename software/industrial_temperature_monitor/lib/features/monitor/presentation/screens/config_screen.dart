import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:industrial_temperature_monitor/core/routing/app_tab.dart';
import 'package:industrial_temperature_monitor/core/theme/app_theme.dart';
import 'package:industrial_temperature_monitor/core/theme/app_card.dart';
import 'package:industrial_temperature_monitor/features/monitor/domain/entities/config_entity.dart';
import 'package:industrial_temperature_monitor/features/monitor/presentation/providers/config_providers.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(configEditProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ref.read(activeTabProvider.notifier).state =
                    AppTab.telemetry,
              ),
              const Text(
                'CONFIGURATION',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: configAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
              error: (err, st) => Text(
                'Config error: $err',
                style: const TextStyle(color: AppColors.alarmCritical),
              ),
              data: (config) => _ConfigForm(config: config),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfigForm extends ConsumerStatefulWidget {
  final ConfigEntity config;
  const _ConfigForm({required this.config});

  @override
  ConsumerState<_ConfigForm> createState() => _ConfigFormState();
}

class _ConfigFormState extends ConsumerState<_ConfigForm> {
  late TextEditingController _targetCtrl;
  late TextEditingController _maxCtrl;
  late TextEditingController _minCtrl;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _targetCtrl = TextEditingController(
      text: widget.config.target.toStringAsFixed(1),
    );
    _maxCtrl = TextEditingController(
      text: widget.config.max.toStringAsFixed(1),
    );
    _minCtrl = TextEditingController(
      text: widget.config.min.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _maxCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = double.tryParse(_targetCtrl.text);
    final max = double.tryParse(_maxCtrl.text);
    final min = double.tryParse(_minCtrl.text);

    if (target == null || max == null || min == null) {
      setState(() => _saveError = 'All fields must be numeric.');
      return;
    }

    final draft = ConfigEntity(target: target, max: max, min: min);
    if (!draft.isValid) {
      setState(() => _saveError = 'Constraint violated: min < target < max');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    ref.read(configEditProvider.notifier).updateDraft(draft);

    try {
      await ref.read(configEditProvider.notifier).save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration pushed to controller.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Push failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SetpointField(
          label: 'Target Temperature',
          icon: Icons.gps_fixed,
          iconColor: AppColors.accentPrimary,
          controller: _targetCtrl,
        ),
        const SizedBox(height: 16),
        _SetpointField(
          label: 'Maximum Limit',
          icon: Icons.north,
          iconColor: AppColors.heating,
          controller: _maxCtrl,
        ),
        const SizedBox(height: 16),
        _SetpointField(
          label: 'Minimum Limit',
          icon: Icons.south,
          iconColor: AppColors.cooling,
          controller: _minCtrl,
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 16),
          Text(
            _saveError!,
            style: const TextStyle(
              color: AppColors.alarmCritical,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
            foregroundColor: const Color(0xFF00171A),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00171A),
                  ),
                )
              : const Text(
                  'SAVE CONFIG',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

class _SetpointField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;

  const _SetpointField({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                suffixText: '°C',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
