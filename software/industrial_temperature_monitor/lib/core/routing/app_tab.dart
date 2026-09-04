import 'package:flutter_riverpod/legacy.dart';

// The three top-level destinations. State-based navigation (rebuild the
// body from this enum) replaces IndexedStack per the spec constraint.
enum AppTab { telemetry, configuration, history }

final activeTabProvider = StateProvider<AppTab>((ref) => AppTab.telemetry);
