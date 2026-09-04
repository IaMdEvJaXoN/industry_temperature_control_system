import 'package:flutter/material.dart';
import 'package:industrial_temperature_monitor/core/constants/app_constants.dart';
import 'package:industrial_temperature_monitor/core/theme/app_theme.dart';
import 'config_screen.dart';

class ConfigGateScreen extends StatefulWidget {
  const ConfigGateScreen({super.key});

  @override
  State<ConfigGateScreen> createState() => _ConfigGateScreenState();
}

class _ConfigGateScreenState extends State<ConfigGateScreen> {
  bool _authenticated = false;
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showPasswordDialog(),
      );
    }
  }

  Future<void> _showPasswordDialog() async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceElevated,
              title: const Text('Authentication Required'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter access code to modify process setpoints.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Access code',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text == ConfigAuth.demoPassword) {
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      setDialogState(() => errorText = 'Incorrect code');
                    }
                  },
                  child: const Text('UNLOCK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _authenticated = result ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      return const ConfigScreen();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Configuration Locked',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => _dialogShown = false);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showPasswordDialog(),
              );
            },
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }
}
