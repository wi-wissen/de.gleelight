import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';

/// Service für lokale Datenpersistierung
class StorageService {
  static const String _keyLamps = 'lamps';
  static const String _keyGroups = 'groups';
  static const String _keyScenes = 'scenes';
  static const String _keyLastSettings = 'last_settings';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  SharedPreferences? _prefs;

  /// Initialisierung
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService nicht initialisiert! Rufe init() auf.');
    }
    return _prefs!;
  }

  // === LAMPEN ===

  /// Alle Lampen laden
  Future<List<Lamp>> loadLamps() async {
    final json = prefs.getString(_keyLamps);
    if (json == null) return [];

    final List<dynamic> data = jsonDecode(json);
    return data.map((item) => Lamp.fromJson(item)).toList();
  }

  /// Lampen speichern
  Future<void> saveLamps(List<Lamp> lamps) async {
    final data = lamps.map((lamp) => lamp.toJson()).toList();
    await prefs.setString(_keyLamps, jsonEncode(data));
  }

  /// Einzelne Lampe aktualisieren
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

  /// Lampe löschen
  Future<void> deleteLamp(String lampId) async {
    final lamps = await loadLamps();
    lamps.removeWhere((l) => l.id == lampId);
    await saveLamps(lamps);
  }

  // === GRUPPEN ===

  /// Alle Gruppen laden
  Future<List<LampGroup>> loadGroups() async {
    final json = prefs.getString(_keyGroups);
    if (json == null) return [];

    final List<dynamic> data = jsonDecode(json);
    return data.map((item) => LampGroup.fromJson(item)).toList();
  }

  /// Gruppen speichern
  Future<void> saveGroups(List<LampGroup> groups) async {
    final data = groups.map((group) => group.toJson()).toList();
    await prefs.setString(_keyGroups, jsonEncode(data));
  }

  /// Einzelne Gruppe aktualisieren
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

  /// Gruppe löschen
  Future<void> deleteGroup(String groupId) async {
    final groups = await loadGroups();
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(groups);
  }

  // === SZENEN ===

  /// Alle Szenen laden
  Future<List<Scene>> loadScenes() async {
    final json = prefs.getString(_keyScenes);
    if (json == null) return [];

    final List<dynamic> data = jsonDecode(json);
    return data.map((item) => Scene.fromJson(item)).toList();
  }

  /// Szenen speichern
  Future<void> saveScenes(List<Scene> scenes) async {
    final data = scenes.map((scene) => scene.toJson()).toList();
    await prefs.setString(_keyScenes, jsonEncode(data));
  }

  /// Szenen für eine Gruppe laden
  Future<List<Scene>> loadScenesForGroup(String groupId) async {
    final scenes = await loadScenes();
    return scenes.where((s) => s.groupId == groupId).toList();
  }

  /// Einzelne Szene aktualisieren
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

  /// Szene löschen
  Future<void> deleteScene(String sceneId) async {
    final scenes = await loadScenes();
    scenes.removeWhere((s) => s.id == sceneId);
    await saveScenes(scenes);
  }

  /// Szenen einer Gruppe löschen
  Future<void> deleteScenesForGroup(String groupId) async {
    final scenes = await loadScenes();
    scenes.removeWhere((s) => s.groupId == groupId);
    await saveScenes(scenes);
  }

  // === LETZTE EINSTELLUNGEN ===

  /// Letzte Einstellungen einer Gruppe speichern
  Future<void> saveLastSettings(String groupId, Map<String, dynamic> settings) async {
    final allSettings = await _loadAllLastSettings();
    allSettings[groupId] = settings;
    await prefs.setString(_keyLastSettings, jsonEncode(allSettings));
  }

  /// Letzte Einstellungen einer Gruppe laden
  Future<Map<String, dynamic>?> loadLastSettings(String groupId) async {
    final allSettings = await _loadAllLastSettings();
    return allSettings[groupId];
  }

  /// Alle letzten Einstellungen laden (privat)
  Future<Map<String, dynamic>> _loadAllLastSettings() async {
    final json = prefs.getString(_keyLastSettings);
    if (json == null) return {};
    
    return Map<String, dynamic>.from(jsonDecode(json));
  }

  // === HILFSMETHODEN ===

  /// System-Gruppen automatisch generieren
  Future<List<LampGroup>> generateSystemGroups(List<Lamp> lamps) async {
    final groups = <LampGroup>[];
    
    // "All" Gruppe
    if (lamps.isNotEmpty) {
      groups.add(LampGroup.all(lamps.map((l) => l.id).toList()));
    }
    
    // Einzellampen-Gruppen
    for (final lamp in lamps) {
      groups.add(LampGroup.single(lamp));
    }
    
    return groups;
  }

  /// Verwaiste Daten bereinigen
  Future<void> cleanup() async {
    final lamps = await loadLamps();
    final groups = await loadGroups();
    final scenes = await loadScenes();
    final lampIds = lamps.map((l) => l.id).toSet();
    
    // Gruppen bereinigen (Lampen-IDs entfernen, die nicht mehr existieren)
    final cleanedGroups = <LampGroup>[];
    for (final group in groups) {
      final validLampIds = group.lampIds.where(lampIds.contains).toList();
      if (validLampIds.isNotEmpty || group.type == GroupType.custom) {
        cleanedGroups.add(group.copyWith(lampIds: validLampIds));
      }
    }
    
    // Szenen bereinigen (Szenen für nicht existierende Gruppen löschen)
    final groupIds = cleanedGroups.map((g) => g.id).toSet();
    final cleanedScenes = scenes.where((s) => groupIds.contains(s.groupId)).toList();
    
    // Bereinigten Daten speichern
    await saveGroups(cleanedGroups);
    await saveScenes(cleanedScenes);
  }

  /// Alle Daten löschen (für Reset/Debug)
  Future<void> clearAll() async {
    await prefs.remove(_keyLamps);
    await prefs.remove(_keyGroups);
    await prefs.remove(_keyScenes);
    await prefs.remove(_keyLastSettings);
  }

  /// Debug: Alle gespeicherten Daten anzeigen
  Future<void> debugPrint() async {
    print('=== STORAGE DEBUG ===');
    print('Lamps: ${await loadLamps()}');
    print('Groups: ${await loadGroups()}');
    print('Scenes: ${await loadScenes()}');
    print('Last Settings: ${prefs.getString(_keyLastSettings)}');
    print('====================');
  }
}