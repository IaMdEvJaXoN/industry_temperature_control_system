import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Plain Container styled to look like a card, used everywhere instead of
// the Card widget + ThemeData.cardTheme, to sidestep the CardTheme /
// CardThemeData type change between Flutter versions.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
