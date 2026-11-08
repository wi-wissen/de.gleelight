import 'package:flutter_test/flutter_test.dart';
import 'package:gleelight/models/lamp.dart';
import 'package:gleelight/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Lamp _lamp(String id) => Lamp(
    id: id,
    name: id,
    model: 'color',
    ip: '10.0.0.1',
    power: false,
    brightness: 100);

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService.instance;
    await storage.init();
    await storage.clearAll();
  });

  test('concurrent lamp updates do not overwrite each other', () async {
    // Discovery reports several lamps at once; each one is stored without
    // waiting for the others. None of them may be lost.
    await Future.wait([
      storage.updateLamp(_lamp('a')),
      storage.updateLamp(_lamp('b')),
      storage.updateLamp(_lamp('c')),
    ]);

    final ids = (await storage.loadLamps()).map((l) => l.id);
    expect(ids, unorderedEquals(['a', 'b', 'c']));
  });

  test('damaged stored data yields an empty list instead of throwing',
      () async {
    await storage.prefs.setString('lamps', '{not json');
    expect(await storage.loadLamps(), isEmpty);
  });
}
