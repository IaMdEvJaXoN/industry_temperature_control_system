// Central constants: RTDB paths, Hive box names, config password.
// Keeping these in one place avoids typo'd path strings scattered
// across the app.

class RtdbPaths {
  // Adjust to match your ESP32 firmware's actual RTDB schema.
  static const String telemetryRoot = '/telemetry';
  static const String configRoot = '/config';
  static const String databaseUrl =
      'https://industry-temp-monitor-default-rtdb.europe-west1.firebasedatabase.app';
}

class HiveBoxes {
  static const String processHistory = 'process_history_box';
  static const String pcbHistory = 'pcb_history_box';
  // Delimiter used to pack "timestamp + entry text" into one raw String,
  // since Hive is used with no generated adapters (spec constraint).
  static const String fieldDelimiter = '|::|';
}

class ConfigAuth {
  // Simple client-side gate only — NOT real access control. Anyone with
  // the APK can read this string. Fine for a demo/internal build; replace
  // with Firebase Auth + RTDB security rules for real deployment.
  static const String demoPassword = 'TEMP';
}
