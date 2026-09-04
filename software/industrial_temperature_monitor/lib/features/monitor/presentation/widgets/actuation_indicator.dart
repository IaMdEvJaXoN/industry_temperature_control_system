import 'package:flutter/material.dart';
import 'package:industrial_temperature_monitor/core/theme/app_theme.dart';

class ActuationIndicator extends StatefulWidget {
  final String state;
  const ActuationIndicator({super.key, required this.state});

  @override
  State<ActuationIndicator> createState() => _ActuationIndicatorState();
}

class _ActuationIndicatorState extends State<ActuationIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state.toUpperCase();
    final isHeating = state == 'HEATING';
    final isCooling = state == 'COOLING';

    final color = isHeating
        ? AppColors.heating
        : isCooling
        ? AppColors.cooling
        : AppColors.idle;

    final icon = isHeating
        ? Icons.local_fire_department
        : isCooling
        ? Icons.ac_unit
        : Icons.power_settings_new;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget iconWidget = Icon(icon, size: 40, color: color);

        if (isCooling) {
          iconWidget = Transform.rotate(
            angle: _controller.value * 6.28319,
            child: iconWidget,
          );
        } else if (isHeating) {
          final t = _controller.value;
          final pulse = 1.0 + 0.15 * (t < 0.5 ? t * 2 : 2 - t * 2);
          iconWidget = Transform.scale(scale: pulse, child: iconWidget);
        }

        return Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(child: iconWidget),
        );
      },
    );
  }
}
