import 'dart:ui';
import '../l10n/app_localizations.dart';
import 'lamp.dart';

/// Data model for a scene (global settings)
class Scene {
  final String id;
  final String name;
  final SceneSettings settings;
  final Color iconColor;
  final DateTime createdAt;

  Scene({
    required this.id,
    required this.name,
    required this.settings,
    this.iconColor = const Color(0xFFFF9800), // Orange for scenes
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with changed values
  Scene copyWith({
    String? name,
    SceneSettings? settings,
    Color? iconColor,
  }) {
    return Scene(
      id: id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      iconColor: iconColor ?? this.iconColor,
      createdAt: createdAt,
    );
  }

  /// Check if scene is applicable to a group of lamps
  bool isApplicableToLamps(List<Lamp> lamps) {
    final onlineLamps = lamps.where((l) => !l.isOffline).toList();
    if (onlineLamps.isEmpty) return false;

    switch (settings.type) {
      case SceneType.colorTemp:
        return onlineLamps.any((l) => l.supportsColorTemp);
      case SceneType.rgb:
        return onlineLamps.any((l) => l.supportsRgb);
      case SceneType.brightness:
        return true; // All lamps support brightness
    }
  }

  /// Check if current lamp settings match this scene
  bool matchesLamps(List<Lamp> lamps,
      {int brightnessTolerance = 5, int colorTempTolerance = 100}) {
    final onlineLamps = lamps.where((l) => !l.isOffline && l.power).toList();
    if (onlineLamps.isEmpty) return false;

    // Calculate average values
    final avgBrightness =
        onlineLamps.map((l) => l.brightness).reduce((a, b) => a + b) ~/
            onlineLamps.length;

    // Check brightness
    if ((avgBrightness - settings.brightness).abs() > brightnessTolerance) {
      return false;
    }

    // Check color temperature (if relevant)
    if (settings.type == SceneType.colorTemp && settings.colorTemp != null) {
      final colorTempLamps =
          onlineLamps.where((l) => l.colorTemp != null).toList();

      if (colorTempLamps.isEmpty) {
        return false;
      }

      final avgColorTemp =
          colorTempLamps.map((l) => l.colorTemp!).reduce((a, b) => a + b) ~/
              colorTempLamps.length;

      if ((avgColorTemp - settings.colorTemp!).abs() > colorTempTolerance) {
        return false;
      }
    }

    // Check RGB color (if relevant)
    if (settings.type == SceneType.rgb && settings.rgb != null) {
      final rgbLamps = onlineLamps.where((l) => l.rgb != null).toList();
      if (rgbLamps.isEmpty) return false;

      // RGB must match exactly
      final allMatch = rgbLamps.every((l) => l.rgb == settings.rgb);
      return allMatch;
    }

    return true;
  }

  /// JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'settings': settings.toJson(),
      'iconColor': iconColor.toARGB32(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// JSON deserialization
  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'],
      name: json['name'],
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
  String toString() => 'Scene(id: $id, name: $name)';
}

/// Scene settings
class SceneSettings {
  final int brightness; // 1-100
  final int? colorTemp; // 1700-6500K (optional)
  final int? rgb; // 0-16777215 (optional)
  final String effect; // "smooth" or "sudden"
  final int duration; // Duration in ms
  final SceneType type;

  const SceneSettings({
    required this.brightness,
    this.colorTemp,
    this.rgb,
    this.effect = 'smooth',
    this.duration = 500,
    this.type = SceneType.brightness,
  });

  /// Create settings for brightness-only scene
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

  /// Create settings for color temperature scene
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

  /// Create settings for RGB color scene
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

  /// Predefined scenes
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

  /// Create a copy with changed values
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

  /// Validate the settings
  bool get isValid {
    if (brightness < 1 || brightness > 100) return false;

    switch (type) {
      case SceneType.colorTemp:
        return colorTemp != null && colorTemp! >= 1700 && colorTemp! <= 6500;
      case SceneType.rgb:
        return rgb != null && rgb! >= 0 && rgb! <= 16777215;
      case SceneType.brightness:
        return true;
    }
  }

  /// Non-localized description (fallback)
  String get description {
    switch (type) {
      case SceneType.brightness:
        return 'Brightness $brightness%';
      case SceneType.colorTemp:
        return 'Brightness $brightness%, ${colorTemp}K';
      case SceneType.rgb:
        return 'Brightness $brightness%, RGB #${rgb!.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
  }

  /// Localized description
  String getLocalizedDescription(AppLocalizations l10n) {
    switch (type) {
      case SceneType.brightness:
        return l10n.brightnessPercent(brightness);
      case SceneType.colorTemp:
        return l10n.brightnessAndColorTemp(brightness, colorTemp!);
      case SceneType.rgb:
        return l10n.brightnessAndRgb(
            brightness, rgb!.toRadixString(16).padLeft(6, '0').toUpperCase());
    }
  }

  /// JSON serialization
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

  /// JSON deserialization
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

/// Scene type
enum SceneType {
  brightness, // Brightness only
  colorTemp, // Brightness + color temperature
  rgb, // Brightness + RGB color
}
