import 'package:hive_flutter/hive_flutter.dart';
import 'package:industrial_temperature_monitor/core/constants/app_constants.dart';

class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(HiveBoxes.processHistory);
    await Hive.openBox<String>(HiveBoxes.pcbHistory);
  }
}
