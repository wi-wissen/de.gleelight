import 'dart:ui';
import 'lamp.dart';

/// Data model for a lamp group
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

  /// Create special "All" group
  factory LampGroup.all(List<String> allLampIds) {
    return LampGroup(
      id: 'all',
      name: 'All',
      lampIds: allLampIds,
      iconColor: const Color(0xFF4CAF50), // Green for "All"
      type: GroupType.all,
    );
  }

  /// Create single lamp group
  factory LampGroup.single(Lamp lamp) {
    return LampGroup(
      id: 'single_${lamp.id}',
      name: lamp.name,
      lampIds: [lamp.id],
      iconColor: lamp.iconColor,
      type: GroupType.single,
    );
  }

  /// Create a copy with changed values
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

  /// Add lamp to group
  LampGroup addLamp(String lampId) {
    if (lampIds.contains(lampId)) return this;
    return copyWith(lampIds: [...lampIds, lampId]);
  }

  /// Remove lamp from group
  LampGroup removeLamp(String lampId) {
    return copyWith(lampIds: lampIds.where((id) => id != lampId).toList());
  }

  /// Check if group contains lamps
  bool get isEmpty => lampIds.isEmpty;

  /// Check if it's a system group (All or Single)
  bool get isSystemGroup => type == GroupType.all || type == GroupType.single;

  /// JSON serialization
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

  /// JSON deserialization
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
  String toString() =>
      'LampGroup(id: $id, name: $name, lamps: ${lampIds.length})';
}

/// Lamp group type
enum GroupType {
  all, // "All" - contains all lamps
  single, // Single lamp as group
  custom, // User-defined group
}

/// Status of a group based on contained lamps
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

  /// Create GroupStatus based on a list of lamps
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

  /// Primary status for UI display
  LampStatus get primaryStatus {
    if (!hasOnlineLamps) return LampStatus.offline;
    if (allOn) return LampStatus.on;
    if (allOff) return LampStatus.off;
    return LampStatus.on; // Mixed status displayed as "on"
  }

  /// Check if status is mixed (some on, some off)
  bool get isMixed => someOn;
}
