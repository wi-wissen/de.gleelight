import 'dart:ui';

/// Data model for a Yeelight lamp with UI-specific properties
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

  // UI-specific properties
  final Color iconColor;
  final DateTime lastSeen;

  /// Whether the control connection to the lamp is up.
  ///
  /// Starts out true for a lamp restored from storage: the lamp is almost
  /// always still there, and assuming otherwise would grey out its button until
  /// discovery has run. It is set to false only once a connection attempt has
  /// actually failed.
  final bool reachable;

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
    this.reachable = true,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// Create a copy with changed values
  Lamp copyWith({
    String? name,
    String? ip,
    bool? power,
    int? brightness,
    int? colorTemp,
    int? rgb,
    List<String>? supportedMethods,
    Color? iconColor,
    bool? reachable,
    DateTime? lastSeen,
  }) {
    return Lamp(
      id: id,
      name: name ?? this.name,
      model: model,
      ip: ip ?? this.ip,
      power: power ?? this.power,
      brightness: brightness ?? this.brightness,
      colorTemp: colorTemp ?? this.colorTemp,
      rgb: rgb ?? this.rgb,
      supportedMethods: supportedMethods ?? this.supportedMethods,
      iconColor: iconColor ?? this.iconColor,
      reachable: reachable ?? this.reachable,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Check if the lamp cannot currently be controlled.
  bool get isOffline => !reachable;

  /// Current status for UI
  LampStatus get status {
    if (isOffline) return LampStatus.offline;
    if (!power) return LampStatus.off;
    return LampStatus.on;
  }

  /// Supports color temperature control
  bool get supportsColorTemp =>
      supportedMethods.contains('set_ct_abx') ||
      model.contains('color') ||
      model.contains('ceiling');

  /// Supports RGB colors
  bool get supportsRgb =>
      supportedMethods.contains('set_rgb') ||
      model.contains('color') ||
      model.contains('stripe');

  /// JSON serialization
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
      'iconColor': iconColor.toARGB32(),
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }

  /// JSON deserialization
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
  String toString() =>
      'Lamp(id: $id, name: $name, power: $power, isOffline: $isOffline)';
}

/// Lamp status for UI display
enum LampStatus {
  on, // On and online
  off, // Off but online
  offline, // Not reachable
}

/// Material Design color palette for lamp icons
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

  /// Get a color based on index
  static Color getColor(int index) {
    return palette[index % palette.length];
  }

  /// Find the index of a color in the palette
  static int getColorIndex(Color color) {
    return palette.indexOf(color);
  }
}
