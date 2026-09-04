import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:industrial_temperature_monitor/core/routing/app_tab.dart';
import 'package:industrial_temperature_monitor/core/theme/app_theme.dart';
import 'package:industrial_temperature_monitor/features/monitor/presentation/providers/history_providers.dart';
import 'config_gate_screen.dart';
import 'history_screen.dart';
import 'telemetry_screen.dart';

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(historyDispatcherProvider);
    final activeTab = ref.watch(activeTabProvider);

    final Widget body;
    switch (activeTab) {
      case AppTab.telemetry:
        body = const TelemetryScreen();
        break;
      case AppTab.configuration:
        body = const ConfigGateScreen();
        break;
      case AppTab.history:
        body = const HistoryScreen();
        break;
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accentPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        currentIndex: activeTab.index,
        onTap: (i) =>
            ref.read(activeTabProvider.notifier).state = AppTab.values[i],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat_outlined),
            label: 'Telemetry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            label: 'Config',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
