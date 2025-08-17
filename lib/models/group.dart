import 'dart:ui';
import 'lamp.dart';

/// Datenmodell für eine Lampengruppe
class LampGroup {
  final String id;
  final String name;
  final List<String> lampIds;
  final Color iconColor;
  final GroupType type;
  final DateTime createdAt;

  LampGroup({
    required this.id,
    required this.name,
    required this.lampIds,
    this.iconColor = const Color(0xFF2196F3),
    this.type = GroupType.custom,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Spezielle "All" Gruppe erstellen
  factory LampGroup.all(List<String> allLampIds) {
    return LampGroup(
      id: 'all',
      name: 'All',
      lampIds: allLampIds,
      iconColor: const Color(0xFF4CAF50), // Grün für "All"
      type: GroupType.all,
    );
  }

  /// Einzellampen-Gruppe erstellen
  factory LampGroup.single(Lamp lamp) {
    return LampGroup(
      id: 'single_${lamp.id}',
      name: lamp.name,
      lampIds: [lamp.id],
      iconColor: lamp.iconColor,
      type: GroupType.single,
    );
  }

  /// Kopie mit geänderten Werten erstellen
  LampGroup copyWith({
    String? name,
    List<String>? lampIds,
    Color? iconColor,
  }) {
    return LampGroup(
      id: id,
      name: name ?? this.name,
      lampIds: lampIds ?? this.lampIds,
      iconColor: iconColor ?? this.iconColor,
      type: type,
      createdAt: createdAt,
    );
  }

  /// Lampe zur Gruppe hinzufügen
  LampGroup addLamp(String lampId) {
    if (lampIds.contains(lampId)) return this;
    return copyWith(lampIds: [...lampIds, lampId]);
  }

  /// Lampe aus Gruppe entfernen
  LampGroup removeLamp(String lampId) {
    return copyWith(lampIds: lampIds.where((id) => id != lampId).toList());
  }

  /// Prüft ob Gruppe Lampen enthält
  bool get isEmpty => lampIds.isEmpty;

  /// Prüft ob es eine System-Gruppe ist (All oder Single)
  bool get isSystemGroup => type == GroupType.all || type == GroupType.single;

  /// JSON Serialisierung
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lampIds': lampIds,
      'iconColor': iconColor.value,
      'type': type.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// JSON Deserialisierung
  factory LampGroup.fromJson(Map<String, dynamic> json) {
    return LampGroup(
      id: json['id'],
      name: json['name'],
      lampIds: List<String>.from(json['lampIds'] ?? []),
      iconColor: Color(json['iconColor'] ?? 0xFF2196F3),
      type: GroupType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => GroupType.custom,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is LampGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LampGroup(id: $id, name: $name, lamps: ${lampIds.length})';
}

/// Typ einer Lampengruppe
enum GroupType {
  all,     // "All" - enthält alle Lampen
  single,  // Einzellampe als Gruppe
  custom,  // Benutzerdefinierte Gruppe
}

/// Status einer Gruppe basierend auf den enthaltenen Lampen
class GroupStatus {
  final bool hasOnlineLamps;
  final bool hasOfflineLamps;
  final bool allOn;
  final bool allOff;
  final bool someOn;
  final int onlineCount;
  final int totalCount;

  const GroupStatus({
    required this.hasOnlineLamps,
    required this.hasOfflineLamps,
    required this.allOn,
    required this.allOff,
    required this.someOn,
    required this.onlineCount,
    required this.totalCount,
  });

  /// Erstellt GroupStatus basierend auf einer Liste von Lampen
  factory GroupStatus.fromLamps(List<Lamp> lamps) {
    final onlineLamps = lamps.where((l) => !l.isOffline).toList();
    final onLamps = onlineLamps.where((l) => l.power).toList();

    return GroupStatus(
      hasOnlineLamps: onlineLamps.isNotEmpty,
      hasOfflineLamps: onlineLamps.length < lamps.length,
      allOn: onlineLamps.isNotEmpty && onLamps.length == onlineLamps.length,
      allOff: onLamps.isEmpty,
      someOn: onLamps.isNotEmpty && onLamps.length < onlineLamps.length,
      onlineCount: onlineLamps.length,
      totalCount: lamps.length,
    );
  }

  /// Hauptstatus für UI-Darstellung
  LampStatus get primaryStatus {
    if (!hasOnlineLamps) return LampStatus.offline;
    if (allOn) return LampStatus.on;
    if (allOff) return LampStatus.off;
    return LampStatus.on; // Gemischter Status wird als "an" dargestellt
  }

  /// Zeigt ob der Status gemischt ist (einige an, einige aus)
  bool get isMixed => someOn;
}