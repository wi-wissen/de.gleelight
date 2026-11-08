import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';

/// Service for local data persistence
class StorageService {
  static const String _keyLamps = 'lamps';
  static const String _keyGroups = 'groups';
  static const String _keyScenes = 'scenes';
  static const String _keyLastSettings = 'last_settings';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  SharedPreferences? _prefs;

  /// Initialization
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized! Call init() first.');
    }
    return _prefs!;
  }

  /// Decode a stored JSON list. A damaged entry (or a format this version
  /// cannot read) is logged and yields an empty list instead of an exception
  /// that would leave the app stuck on startup.
  ///
  /// Synchronous on purpose, like [_writeList]: the update/delete helpers
  /// read, modify and write without an `await` in between. With one, two
  /// concurrent updates (e.g. several lamps discovered at once) would each
  /// start from the old list and the second write would drop the first lamp.
  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final json = prefs.getString(key);
    if (json == null) return [];
    try {
      final data = jsonDecode(json) as List<dynamic>;
      return data
          .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      developer.log('Could not read "$key": $e', name: 'storage');
      return [];
    }
  }

  /// setString updates the in-memory cache before it returns; only the write
  /// to disk is asynchronous.
  Future<void> _writeList(String key, List<Map<String, dynamic>> data) {
    return prefs.setString(key, jsonEncode(data));
  }

  /// Replace the entry with the same id, or append it.
  Future<void> _upsert<T>(
    String key,
    T item,
    T Function(Map<String, dynamic>) fromJson,
    String Function(T) idOf,
    Map<String, dynamic> Function(T) toJson,
  ) {
    final items = _readList(key, fromJson);
    final index = items.indexWhere((i) => idOf(i) == idOf(item));
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
    return _writeList(key, items.map(toJson).toList());
  }

  Future<void> _remove<T>(
    String key,
    String id,
    T Function(Map<String, dynamic>) fromJson,
    String Function(T) idOf,
    Map<String, dynamic> Function(T) toJson,
  ) {
    final items = _readList(key, fromJson)..removeWhere((i) => idOf(i) == id);
    return _writeList(key, items.map(toJson).toList());
  }

  // === LAMPS ===

  Future<List<Lamp>> loadLamps() async => _readList(_keyLamps, Lamp.fromJson);

  Future<void> saveLamps(List<Lamp> lamps) =>
      _writeList(_keyLamps, lamps.map((l) => l.toJson()).toList());

  Future<void> updateLamp(Lamp lamp) => _upsert<Lamp>(
      _keyLamps, lamp, Lamp.fromJson, (l) => l.id, (l) => l.toJson());

  Future<void> deleteLamp(String lampId) => _remove<Lamp>(
      _keyLamps, lampId, Lamp.fromJson, (l) => l.id, (l) => l.toJson());

  // === GROUPS ===

  Future<List<LampGroup>> loadGroups() async =>
      _readList(_keyGroups, LampGroup.fromJson);

  Future<void> saveGroups(List<LampGroup> groups) =>
      _writeList(_keyGroups, groups.map((g) => g.toJson()).toList());

  Future<void> updateGroup(LampGroup group) => _upsert<LampGroup>(
      _keyGroups, group, LampGroup.fromJson, (g) => g.id, (g) => g.toJson());

  Future<void> deleteGroup(String groupId) => _remove<LampGroup>(
      _keyGroups, groupId, LampGroup.fromJson, (g) => g.id, (g) => g.toJson());

  // === SCENES (GLOBAL) ===

  Future<List<Scene>> loadScenes() async =>
      _readList(_keyScenes, Scene.fromJson);

  Future<void> saveScenes(List<Scene> scenes) =>
      _writeList(_keyScenes, scenes.map((s) => s.toJson()).toList());

  Future<void> updateScene(Scene scene) => _upsert<Scene>(
      _keyScenes, scene, Scene.fromJson, (s) => s.id, (s) => s.toJson());

  Future<void> deleteScene(String sceneId) => _remove<Scene>(
      _keyScenes, sceneId, Scene.fromJson, (s) => s.id, (s) => s.toJson());

  /// Filter scenes applicable to a group
  Future<List<Scene>> getScenesForGroup(List<Lamp> groupLamps) async {
    final scenes = await loadScenes();
    return scenes
        .where((scene) => scene.isApplicableToLamps(groupLamps))
        .toList();
  }

  // === LAST SETTINGS ===

  /// Save last settings for a group
  Future<void> saveLastSettings(
      String groupId, Map<String, dynamic> settings) async {
    final allSettings = _loadAllLastSettings();
    allSettings[groupId] = settings;
    await prefs.setString(_keyLastSettings, jsonEncode(allSettings));
  }

  /// Load last settings for a group
  Future<Map<String, dynamic>?> loadLastSettings(String groupId) async {
    final settings = _loadAllLastSettings()[groupId];
    return settings is Map ? Map<String, dynamic>.from(settings) : null;
  }

  /// Load all last settings (private)
  Map<String, dynamic> _loadAllLastSettings() {
    final json = prefs.getString(_keyLastSettings);
    if (json == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (e) {
      developer.log('Could not read last settings: $e', name: 'storage');
      return {};
    }
  }

  // === HELPER METHODS ===

  /// Automatically generate system groups
  Future<List<LampGroup>> generateSystemGroups(List<Lamp> lamps) async {
    final groups = <LampGroup>[];

    // "All" group
    if (lamps.isNotEmpty) {
      groups.add(LampGroup.all(lamps.map((l) => l.id).toList()));
    }

    // Single lamp groups
    for (final lamp in lamps) {
      groups.add(LampGroup.single(lamp));
    }

    return groups;
  }

  /// Clean up orphaned data
  Future<void> cleanup() async {
    final lamps = await loadLamps();
    final groups = await loadGroups();
    final scenes = await loadScenes();
    final lampIds = lamps.map((l) => l.id).toSet();

    // Clean up groups (remove lamp IDs that no longer exist)
    final cleanedGroups = <LampGroup>[];
    for (final group in groups) {
      final validLampIds = group.lampIds.where(lampIds.contains).toList();
      if (validLampIds.isNotEmpty || group.type == GroupType.custom) {
        cleanedGroups.add(group.copyWith(lampIds: validLampIds));
      }
    }

    // Clean up scenes - stay global, no group-specific cleanup needed
    // Scenes are only deleted if explicitly no longer applicable
    final cleanedScenes = scenes.where((scene) {
      // Keep scenes applicable to at least one lamp
      return scene.isApplicableToLamps(lamps);
    }).toList();

    // Save cleaned data
    await saveGroups(cleanedGroups);
    await saveScenes(cleanedScenes);
  }

  /// Delete all data (for reset/debug)
  Future<void> clearAll() async {
    await prefs.remove(_keyLamps);
    await prefs.remove(_keyGroups);
    await prefs.remove(_keyScenes);
    await prefs.remove(_keyLastSettings);
  }

  /// Debug: Print all stored data (development only)
  Future<void> debugPrint() async {
    // Debug output only in debug mode
    assert(() {
      final lampsFuture = loadLamps();
      final groupsFuture = loadGroups();
      final scenesFuture = loadScenes();
      final lastSettings = prefs.getString(_keyLastSettings);

      lampsFuture
          .then((lamps) => developer.log('Lamps: $lamps', name: 'storage'));
      groupsFuture
          .then((groups) => developer.log('Groups: $groups', name: 'storage'));
      scenesFuture
          .then((scenes) => developer.log('Scenes: $scenes', name: 'storage'));
      developer.log('Last Settings: $lastSettings', name: 'storage');
      return true;
    }());
  }
}
