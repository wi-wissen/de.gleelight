import 'dart:ui';

/// Datenmodell für eine Szene (vordefinierte Einstellungen)
class Scene {
  final String id;
  final String name;
  final String groupId;
  final SceneSettings settings;
  final Color iconColor;
  final DateTime createdAt;

  Scene({
    required this.id,
    required this.name,
    required this.groupId,
    required this.settings,
    this.iconColor = const Color(0xFFFF9800), // Orange für Szenen
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Kopie mit geänderten Werten erstellen
  Scene copyWith({
    String? name,
    String? groupId,
    SceneSettings? settings,
    Color? iconColor,
  }) {
    return Scene(
      id: id,
      name: name ?? this.name,
      groupId: groupId ?? this.groupId,
      settings: settings ?? this.settings,
      iconColor: iconColor ?? this.iconColor,
      createdAt: createdAt,
    );
  }

  /// JSON Serialisierung
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupId': groupId,
      'settings': settings.toJson(),
      'iconColor': iconColor.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// JSON Deserialisierung
  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'],
      name: json['name'],
      groupId: json['groupId'],
      settings: SceneSettings.fromJson(json['settings']),
      iconColor: Color(json['iconColor'] ?? 0xFFFF9800),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Scene && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Scene(id: $id, name: $name, group: $groupId)';
}

/// Einstellungen einer Szene
class SceneSettings {
  final int brightness;           // 1-100
  final int? colorTemp;          // 1700-6500K (optional)
  final int? rgb;                // 0-16777215 (optional)
  final String effect;           // "smooth" or "sudden"
  final int duration;            // Dauer in ms
  final SceneType type;

  const SceneSettings({
    required this.brightness,
    this.colorTemp,
    this.rgb,
    this.effect = 'smooth',
    this.duration = 500,
    this.type = SceneType.brightness,
  });

  /// Erstellt Einstellungen für reine Helligkeits-Szene
  factory SceneSettings.brightness({
    required int brightness,
    String effect = 'smooth',
    int duration = 500,
  }) {
    return SceneSettings(
      brightness: brightness,
      effect: effect,
      duration: duration,
      type: SceneType.brightness,
    );
  }

  /// Erstellt Einstellungen für Farbtemperatur-Szene
  factory SceneSettings.colorTemp({
    required int brightness,
    required int colorTemp,
    String effect = 'smooth',
    int duration = 500,
  }) {
    return SceneSettings(
      brightness: brightness,
      colorTemp: colorTemp,
      effect: effect,
      duration: duration,
      type: SceneType.colorTemp,
    );
  }

  /// Erstellt Einstellungen für RGB-Farb-Szene
  factory SceneSettings.rgb({
    required int brightness,
    required int rgb,
    String effect = 'smooth',
    int duration = 500,
  }) {
    return SceneSettings(
      brightness: brightness,
      rgb: rgb,
      effect: effect,
      duration: duration,
      type: SceneType.rgb,
    );
  }

  /// Vordefinierte Szenen
  static const SceneSettings warm = SceneSettings(
    brightness: 80,
    colorTemp: 2700,
    type: SceneType.colorTemp,
  );

  static const SceneSettings cool = SceneSettings(
    brightness: 100,
    colorTemp: 6500,
    type: SceneType.colorTemp,
  );

  static const SceneSettings dim = SceneSettings(
    brightness: 20,
    colorTemp: 2700,
    type: SceneType.colorTemp,
  );

  static const SceneSettings bright = SceneSettings(
    brightness: 100,
    colorTemp: 4000,
    type: SceneType.colorTemp,
  );

  /// Kopie mit geänderten Werten erstellen
  SceneSettings copyWith({
    int? brightness,
    int? colorTemp,
    int? rgb,
    String? effect,
    int? duration,
    SceneType? type,
  }) {
    return SceneSettings(
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      rgb: rgb ?? this.rgb,
      effect: effect ?? this.effect,
      duration: duration ?? this.duration,
      type: type ?? this.type,
    );
  }

  /// Validiert die Einstellungen
  bool get isValid {
    if (brightness < 1 || brightness > 100) return false;
    
    switch (type) {
      case SceneType.colorTemp:
        return colorTemp != null && 
               colorTemp! >= 1700 && 
               colorTemp! <= 6500;
      case SceneType.rgb:
        return rgb != null && 
               rgb! >= 0 && 
               rgb! <= 16777215;
      case SceneType.brightness:
        return true;
    }
  }

  /// Beschreibung der Einstellungen
  String get description {
    switch (type) {
      case SceneType.brightness:
        return 'Helligkeit $brightness%';
      case SceneType.colorTemp:
        return 'Helligkeit $brightness%, ${colorTemp}K';
      case SceneType.rgb:
        return 'Helligkeit $brightness%, RGB #${rgb!.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
  }

  /// JSON Serialisierung
  Map<String, dynamic> toJson() {
    return {
      'brightness': brightness,
      'colorTemp': colorTemp,
      'rgb': rgb,
      'effect': effect,
      'duration': duration,
      'type': type.name,
    };
  }

  /// JSON Deserialisierung
  factory SceneSettings.fromJson(Map<String, dynamic> json) {
    return SceneSettings(
      brightness: json['brightness'] ?? 100,
      colorTemp: json['colorTemp'],
      rgb: json['rgb'],
      effect: json['effect'] ?? 'smooth',
      duration: json['duration'] ?? 500,
      type: SceneType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SceneType.brightness,
      ),
    );
  }

  @override
  String toString() => 'SceneSettings($description)';
}

/// Typ einer Szene
enum SceneType {
  brightness,  // Nur Helligkeit
  colorTemp,   // Helligkeit + Farbtemperatur
  rgb,         // Helligkeit + RGB-Farbe
}