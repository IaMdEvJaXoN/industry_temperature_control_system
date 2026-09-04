import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:industrial_temperature_monitor/core/constants/app_constants.dart';
import 'package:industrial_temperature_monitor/core/theme/app_theme.dart';
import 'package:industrial_temperature_monitor/core/theme/app_card.dart';
import 'package:industrial_temperature_monitor/features/monitor/presentation/providers/history_providers.dart';

class HistoryLogScreen extends ConsumerWidget {
  final String title;
  final bool isPcb;

  const HistoryLogScreen({super.key, required this.title, required this.isPcb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(
      isPcb ? pcbHistoryProvider : processHistoryProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title.toUpperCase())),
      body: logAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary),
        ),
        error: (err, st) => Center(
          child: Text(
            'Failed to read log: $err',
            style: const TextStyle(color: AppColors.alarmCritical),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text(
                'No entries logged yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final parts = entries[i].split(HiveBoxes.fieldDelimiter);
              final timestamp = parts.isNotEmpty ? parts[0] : '';
              final body = parts.length > 1
                  ? parts.sublist(1).join(HiveBoxes.fieldDelimiter)
                  : entries[i];

              return AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 10),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.accentSecondary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            body,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timestamp,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
