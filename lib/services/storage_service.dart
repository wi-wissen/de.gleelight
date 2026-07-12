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

  // === LAMPS ===

  /// Load all lamps
  Future<List<Lamp>> loadLamps() async {
    final json = prefs.getString(_keyLamps);
    if (json == null) return [];

    final List<dynamic> data = jsonDecode(json);
    return data.map((item) => Lamp.fromJson(item)).toList();
  }

  /// Save lamps
  Future<void> saveLamps(List<Lamp> lamps) async {
    final data = lamps.map((lamp) => lamp.toJson()).toList();
    await prefs.setString(_keyLamps, jsonEncode(data));
  }

  /// Update single lamp
  Future<void> updateLamp(Lamp lamp) async {
    final lamps = await loadLamps();
    final index = lamps.indexWhere((l) => l.id == lamp.id);

    if (index >= 0) {
      lamps[index] = lamp;
    } else {
      lamps.add(lamp);
    }

    await saveLamps(lamps);
  }

  /// Delete lamp
  Future<void> deleteLamp(String lampId) async {
    final lamps = await loadLamps();
    lamps.removeWhere((l) => l.id == lampId);
    await saveLamps(lamps);
  }

  // === GROUPS ===

  /// Load all groups
  Future<List<LampGroup>> loadGroups() async {
    final json = prefs.getString(_keyGroups);
    if (json == null) return [];

    final List<dynamic> data = jsonDecode(json);
    return data.map((item) => LampGroup.fromJson(item)).toList();
  }

  /// Save groups
  Future<void> saveGroups(List<LampGroup> groups) async {
    final data = groups.map((group) => group.toJson()).toList();
    await prefs.setString(_keyGroups, jsonEncode(data));
  }

  /// Update single group
  Future<void> updateGroup(LampGroup group) async {
    final groups = await loadGroups();
    final index = groups.indexWhere((g) => g.id == group.id);

    if (index >= 0) {
      groups[index] = group;
    } else {
      groups.add(group);
    }

    await saveGroups(groups);
  }

  /// Delete group
  Future<void> deleteGroup(String groupId) async {
    final groups = await loadGroups();
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(groups);
  }

  // === SCENES (GLOBAL) ===

  /// Load all scenes
  Future<List<Scene>> loadScenes() async {
    final json = prefs.getString(_keyScenes);
    if (json == null) return [];

    final List<dynamic> data = jsonDecode(json);
    return data.map((item) => Scene.fromJson(item)).toList();
  }

  /// Save scenes
  Future<void> saveScenes(List<Scene> scenes) async {
    final data = scenes.map((scene) => scene.toJson()).toList();
    await prefs.setString(_keyScenes, jsonEncode(data));
  }

  /// Update single scene
  Future<void> updateScene(Scene scene) async {
    final scenes = await loadScenes();
    final index = scenes.indexWhere((s) => s.id == scene.id);

    if (index >= 0) {
      scenes[index] = scene;
    } else {
      scenes.add(scene);
    }

    await saveScenes(scenes);
  }

  /// Delete scene
  Future<void> deleteScene(String sceneId) async {
    final scenes = await loadScenes();
    scenes.removeWhere((s) => s.id == sceneId);
    await saveScenes(scenes);
  }

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
    final allSettings = await _loadAllLastSettings();
    allSettings[groupId] = settings;
    await prefs.setString(_keyLastSettings, jsonEncode(allSettings));
  }

  /// Load last settings for a group
  Future<Map<String, dynamic>?> loadLastSettings(String groupId) async {
    final allSettings = await _loadAllLastSettings();
    return allSettings[groupId];
  }

  /// Load all last settings (private)
  Future<Map<String, dynamic>> _loadAllLastSettings() async {
    final json = prefs.getString(_keyLastSettings);
    if (json == null) return {};

    return Map<String, dynamic>.from(jsonDecode(json));
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
