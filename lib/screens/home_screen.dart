import 'package:flutter/material.dart';
import 'dart:async';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';
import '../services/yeelight_service.dart';
import '../services/storage_service.dart';
import '../widgets/group_card.dart';
import '../screens/settings_screen.dart';
import '../screens/scenes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YeelightService _yeelightService = YeelightService();
  final StorageService _storage = StorageService.instance;
  
  List<Lamp> _lamps = [];
  List<LampGroup> _groups = [];
  List<Scene> _scenes = [];
  bool _isDiscovering = false;
  StreamSubscription? _deviceSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _yeelightService.stopDiscovery();
    super.dispose();
  }

  /// App initialisieren
  Future<void> _initialize() async {
    await _loadData();
    await _startDiscovery();
  }

  /// Gespeicherte Daten laden
  Future<void> _loadData() async {
    final lamps = await _storage.loadLamps();
    final groups = await _storage.loadGroups();
    final scenes = await _storage.loadScenes();
    
    setState(() {
      _lamps = lamps;
      _groups = groups;
      _scenes = scenes;
    });
    
    // Automatische System-Gruppen generieren wenn nötig
    await _updateSystemGroups();
  }

  /// Lampenerkennung starten
  Future<void> _startDiscovery() async {
    setState(() => _isDiscovering = true);
    
    // Auf neue Lampen hören
    _deviceSubscription = _yeelightService.deviceStream.listen((device) async {
      await _onDeviceDiscovered(device);
    });
    
    await _yeelightService.startDiscovery();
    
    // Discovery läuft im Hintergrund weiter
    setState(() => _isDiscovering = false);
  }

  /// Neue Lampe entdeckt
  Future<void> _onDeviceDiscovered(YeelightDevice device) async {
    final existingIndex = _lamps.indexWhere((l) => l.id == device.id);
    
    Lamp lamp;
    if (existingIndex >= 0) {
      // Existierende Lampe aktualisieren
      lamp = _lamps[existingIndex].copyWith(
        name: device.name,
        power: device.power,
        brightness: device.brightness,
        colorTemp: device.colorTemp,
        rgb: device.rgb,
        isOnline: true,
        lastSeen: DateTime.now(),
      );
      _lamps[existingIndex] = lamp;
    } else {
      // Neue Lampe hinzufügen
      final colorIndex = _lamps.length % LampColors.palette.length;
      lamp = Lamp(
        id: device.id,
        name: device.name,
        model: device.model,
        ip: device.ip,
        power: device.power,
        brightness: device.brightness,
        colorTemp: device.colorTemp,
        rgb: device.rgb,
        supportedMethods: device.supportedMethods,
        iconColor: LampColors.getColor(colorIndex),
      );
      _lamps.add(lamp);
    }
    
    await _storage.updateLamp(lamp);
    await _updateSystemGroups();
    setState(() {});
  }

  /// System-Gruppen aktualisieren
  Future<void> _updateSystemGroups() async {
    final systemGroups = await _storage.generateSystemGroups(_lamps);
    
    // Bestehende Custom-Gruppen beibehalten
    final customGroups = _groups.where((g) => g.type == GroupType.custom).toList();
    
    _groups = [...systemGroups, ...customGroups];
    await _storage.saveGroups(_groups);
  }

  /// Manuelle Aktualisierung
  Future<void> _refresh() async {
    await _startDiscovery();
    
    // Offline-Status für alte Lampen setzen
    final now = DateTime.now();
    for (int i = 0; i < _lamps.length; i++) {
      final lamp = _lamps[i];
      if (now.difference(lamp.lastSeen).inMinutes > 2) {
        _lamps[i] = lamp.copyWith(isOnline: false);
        await _storage.updateLamp(_lamps[i]);
      }
    }
    
    setState(() {});
  }

  /// Neue Gruppe erstellen
  Future<void> _createGroup() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateGroupDialog(lamps: _lamps),
    );
    
    if (result != null && result.isNotEmpty) {
      final group = LampGroup(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: result,
        lampIds: [],
        iconColor: LampColors.getColor(_groups.length),
        type: GroupType.custom,
      );
      
      _groups.add(group);
      await _storage.updateGroup(group);
      setState(() {});
    }
  }

  /// Gruppe an/aus schalten
  Future<void> _toggleGroup(LampGroup group) async {
    final groupLamps = _lamps.where((l) => group.lampIds.contains(l.id)).toList();
    final onlineLamps = groupLamps.where((l) => !l.isOffline).toList();
    
    if (onlineLamps.isEmpty) return;
    
    // Status der Gruppe bestimmen
    final status = GroupStatus.fromLamps(onlineLamps);
    final targetPower = !status.allOn;
    
    // Alle Lampen der Gruppe schalten
    for (final lamp in onlineLamps) {
      await _yeelightService.setPower(lamp.ip, targetPower);
      
      // Lokalen Status aktualisieren
      final index = _lamps.indexWhere((l) => l.id == lamp.id);
      if (index >= 0) {
        _lamps[index] = lamp.copyWith(power: targetPower);
        await _storage.updateLamp(_lamps[index]);
      }
    }
    
    setState(() {});
  }

  /// Gruppe bearbeiten (Einstellungen)
  void _editGroup(LampGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          group: group,
          lamps: _lamps.where((l) => group.lampIds.contains(l.id)).toList(),
        ),
      ),
    );
  }

  /// Szenen für Gruppe anzeigen
  void _showScenes(LampGroup group) {
    final groupScenes = _scenes.where((s) => s.groupId == group.id).toList();
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScenesScreen(
          group: group,
          scenes: groupScenes,
          lamps: _lamps.where((l) => group.lampIds.contains(l.id)).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gruppen sortieren: All, dann Custom, dann Einzellampen
    final sortedGroups = [..._groups];
    sortedGroups.sort((a, b) {
      if (a.type == GroupType.all) return -1;
      if (b.type == GroupType.all) return 1;
      if (a.type == GroupType.custom && b.type == GroupType.single) return -1;
      if (a.type == GroupType.single && b.type == GroupType.custom) return 1;
      return a.name.compareTo(b.name);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('GleeLight'),
        actions: [
          IconButton(
            icon: _isDiscovering 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
            onPressed: _isDiscovering ? null : _refresh,
          ),
        ],
      ),
      
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _groups.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedGroups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = sortedGroups[index];
                final groupLamps = _lamps
                    .where((l) => group.lampIds.contains(l.id))
                    .toList();
                
                return GroupCard(
                  group: group,
                  lamps: groupLamps,
                  onToggle: () => _toggleGroup(group),
                  onSettings: () => _editGroup(group),
                  onScenes: () => _showScenes(group),
                );
              },
            ),
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        tooltip: 'Neue Gruppe',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog zum Erstellen einer neuen Gruppe
class _CreateGroupDialog extends StatefulWidget {
  final List<Lamp> lamps;

  const _CreateGroupDialog({required this.lamps});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Gruppe'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Gruppenname',
          hintText: 'z.B. Wohnzimmer',
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}

/// Leerer Zustand wenn keine Lampen gefunden
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Keine Lampen gefunden',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ziehe nach unten um zu aktualisieren\noder stelle sicher, dass deine\nYeelight-Lampen eingeschaltet sind.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}