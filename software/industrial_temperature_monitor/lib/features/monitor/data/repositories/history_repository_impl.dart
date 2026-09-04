import 'package:hive/hive.dart';
import '../../domain/repositories/telemetry_repository.dart';
import '../../../../core/constants/app_constants.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  Box<String> get _processBox => Hive.box<String>(HiveBoxes.processHistory);
  Box<String> get _pcbBox => Hive.box<String>(HiveBoxes.pcbHistory);

  String _encode(String rawEntry) {
    final ts = DateTime.now().toIso8601String();
    return '$ts${HiveBoxes.fieldDelimiter}$rawEntry';
  }

  @override
  Future<void> appendProcessLog(String rawEntry) async {
    await _processBox.add(_encode(rawEntry));
  }

  @override
  Future<void> appendPcbLog(String rawEntry) async {
    await _pcbBox.add(_encode(rawEntry));
  }

  List<String> _sortedValues(Box<String> box) {
    return box.values.toList().reversed.toList();
  }

  Stream<List<String>> _watchBox(Box<String> box) async* {
    yield _sortedValues(box);
    await for (final _ in box.watch()) {
      yield _sortedValues(box);
    }
  }

  @override
  Stream<List<String>> watchProcessLog() => _watchBox(_processBox);

  @override
  Stream<List<String>> watchPcbLog() => _watchBox(_pcbBox);
}
