import 'dart:ui';

/// Datenmodell für eine Yeelight-Lampe mit UI-spezifischen Eigenschaften
class Lamp {
  final String id;
  final String name;
  final String model;
  final String ip;
  final bool power;
  final int brightness;
  final int? colorTemp;
  final int? rgb;
  final List<String> supportedMethods;
  
  // UI-spezifische Eigenschaften
  final Color iconColor;
  final bool isOnline;
  final DateTime lastSeen;
  
  Lamp({
    required this.id,
    required this.name,
    required this.model,
    required this.ip,
    required this.power,
    required this.brightness,
    this.colorTemp,
    this.rgb,
    this.supportedMethods = const [],
    this.iconColor = const Color(0xFF2196F3), // Material Blue
    this.isOnline = true,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// Kopie mit geänderten Werten erstellen
  Lamp copyWith({
    String? name,
    bool? power,
    int? brightness,
    int? colorTemp,
    int? rgb,
    Color? iconColor,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return Lamp(
      id: id,
      name: name ?? this.name,
      model: model,
      ip: ip,
      power: power ?? this.power,
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      rgb: rgb ?? this.rgb,
      supportedMethods: supportedMethods,
      iconColor: iconColor ?? this.iconColor,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Prüft ob Lampe als offline gilt (>2 Minuten nicht gesehen)
  bool get isOffline {
    return DateTime.now().difference(lastSeen).inMinutes > 2;
  }

  /// Aktueller Status für UI
  LampStatus get status {
    if (isOffline) return LampStatus.offline;
    if (!power) return LampStatus.off;
    return LampStatus.on;
  }

  /// Unterstützt Farbtemperatur-Steuerung
  bool get supportsColorTemp => 
    supportedMethods.contains('set_ct_abx') || 
    model.contains('color') || 
    model.contains('ceiling');

  /// Unterstützt RGB-Farben
  bool get supportsRgb => 
    supportedMethods.contains('set_rgb') || 
    model.contains('color') || 
    model.contains('stripe');

  /// JSON Serialisierung
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'ip': ip,
      'power': power,
      'brightness': brightness,
      'colorTemp': colorTemp,
      'rgb': rgb,
      'supportedMethods': supportedMethods,
      'iconColor': iconColor.value,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }

  /// JSON Deserialisierung
  factory Lamp.fromJson(Map<String, dynamic> json) {
    return Lamp(
      id: json['id'],
      name: json['name'],
      model: json['model'] ?? 'unknown',
      ip: json['ip'],
      power: json['power'] ?? false,
      brightness: json['brightness'] ?? 100,
      colorTemp: json['colorTemp'],
      rgb: json['rgb'],
      supportedMethods: List<String>.from(json['supportedMethods'] ?? []),
      iconColor: Color(json['iconColor'] ?? 0xFF2196F3),
      isOnline: json['isOnline'] ?? true,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        json['lastSeen'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Lamp && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Lamp(id: $id, name: $name, power: $power, online: $isOnline)';
}

/// Status einer Lampe für UI-Darstellung
enum LampStatus {
  on,     // An und online
  off,    // Aus aber online
  offline, // Nicht erreichbar
}

/// Material Design Farbpalette für Lampen-Icons
class LampColors {
  static const List<Color> palette = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFFE91E63), // Pink
    Color(0xFF3F51B5), // Indigo
    Color(0xFF009688), // Teal
  ];

  /// Gibt eine Farbe basierend auf dem Index zurück
  static Color getColor(int index) {
    return palette[index % palette.length];
  }

  /// Findet den Index einer Farbe in der Palette
  static int getColorIndex(Color color) {
    return palette.indexOf(color);
  }
}