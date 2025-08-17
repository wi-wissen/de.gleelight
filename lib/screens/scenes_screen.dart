import 'package:flutter/material.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';
import '../services/yeelight_service.dart';
import '../services/storage_service.dart';

class ScenesScreen extends StatefulWidget {
  final LampGroup group;
  final List<Scene> scenes;
  final List<Lamp> lamps;

  const ScenesScreen({
    super.key,
    required this.group,
    required this.scenes,
    required this.lamps,
  });

  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  final YeelightService _yeelightService = YeelightService();
  final StorageService _storage = StorageService.instance;
  
  List<Scene> _scenes = [];
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _scenes = [...widget.scenes];
    _addDefaultScenesIfEmpty();
  }

  /// Standard-Szenen hinzufügen wenn noch keine existieren
  void _addDefaultScenesIfEmpty() {
    if (_scenes.isEmpty) {
      final defaultScenes = [
        Scene(
          id: '${widget.group.id}_warm',
          name: 'Warm',
          groupId: widget.group.id,
          settings: SceneSettings.warm,
          iconColor: const Color(0xFFFF9800),
        ),
        Scene(
          id: '${widget.group.id}_bright',
          name: 'Hell',
          groupId: widget.group.id,
          settings: SceneSettings.bright,
          iconColor: const Color(0xFF2196F3),
        ),
        Scene(
          id: '${widget.group.id}_dim',
          name: 'Gedimmt',
          groupId: widget.group.id,
          settings: SceneSettings.dim,
          iconColor: const Color(0xFF9C27B0),
        ),
      ];
      
      setState(() {
        _scenes = defaultScenes;
      });
      
      // Standard-Szenen speichern
      for (final scene in defaultScenes) {
        _storage.updateScene(scene);
      }
    }
  }

  /// Szene anwenden
  Future<void> _applyScene(Scene scene) async {
    if (_isApplying) return;
    
    setState(() => _isApplying = true);
    
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();
    
    for (final lamp in onlineLamps) {
      // Lampe einschalten falls sie aus ist
      if (!lamp.power) {
        await _yeelightService.setPower(lamp.ip, true);
      }
      
      // Helligkeit setzen
      await _yeelightService.setBrightness(
        lamp.ip, 
        scene.settings.brightness,
      );
      
      // Je nach Szenen-Typ weitere Einstellungen
      switch (scene.settings.type) {
        case SceneType.colorTemp:
          if (scene.settings.colorTemp != null && lamp.supportsColorTemp) {
            await _yeelightService.setColorTemp(
              lamp.ip, 
              scene.settings.colorTemp!,
            );
          }
          break;
        case SceneType.rgb:
          if (scene.settings.rgb != null && lamp.supportsRgb) {
            await _yeelightService.setRgb(
              lamp.ip, 
              scene.settings.rgb!,
            );
          }
          break;
        case SceneType.brightness:
          // Nur Helligkeit, bereits gesetzt
          break;
      }
    }
    
    setState(() => _isApplying = false);
    
    // Erfolgsmeldung
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Szene "${scene.name}" angewendet'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  /// Neue Szene erstellen
  Future<void> _createScene() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateSceneDialog(
        groupName: widget.group.name,
        lamps: widget.lamps,
      ),
    );
    
    if (result != null) {
      final scene = Scene(
        id: '${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}',
        name: result['name'],
        groupId: widget.group.id,
        settings: result['settings'],
        iconColor: result['color'],
      );
      
      setState(() {
        _scenes.add(scene);
      });
      
      await _storage.updateScene(scene);
    }
  }

  /// Szene löschen
  Future<void> _deleteScene(Scene scene) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Szene löschen'),
        content: Text('Möchtest du die Szene "${scene.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _scenes.removeWhere((s) => s.id == scene.id);
      });
      
      await _storage.deleteScene(scene.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group.name} - Szenen'),
        actions: [
          if (onlineLamps.isNotEmpty)
            IconButton(
              onPressed: _createScene,
              icon: const Icon(Icons.add),
              tooltip: 'Neue Szene',
            ),
        ],
      ),
      
      body: onlineLamps.isEmpty 
        ? const _OfflineState()
        : _scenes.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _scenes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final scene = _scenes[index];
                return _SceneCard(
                  scene: scene,
                  isApplying: _isApplying,
                  onApply: () => _applyScene(scene),
                  onDelete: () => _deleteScene(scene),
                );
              },
            ),
    );
  }
}

/// Szenen-Karte
class _SceneCard extends StatelessWidget {
  final Scene scene;
  final bool isApplying;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  const _SceneCard({
    required this.scene,
    required this.isApplying,
    required this.onApply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: isApplying ? null : onApply,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scene.iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.palette,
                  color: scene.iconColor,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Name und Beschreibung
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scene.settings.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Delete Button
              IconButton(
                onPressed: isApplying ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Löschen',
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog zum Erstellen einer neuen Szene
class _CreateSceneDialog extends StatefulWidget {
  final String groupName;
  final List<Lamp> lamps;

  const _CreateSceneDialog({
    required this.groupName,
    required this.lamps,
  });

  @override
  State<_CreateSceneDialog> createState() => _CreateSceneDialogState();
}

class _CreateSceneDialogState extends State<_CreateSceneDialog> {
  final _nameController = TextEditingController();
  double _brightness = 80;
  double _colorTemp = 4000;
  int _selectedColorIndex = 1; // Orange
  
  static const _colors = [
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange  
    Color(0xFF9C27B0), // Purple
    Color(0xFF4CAF50), // Green
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    final settings = SceneSettings.colorTemp(
      brightness: _brightness.round(),
      colorTemp: _colorTemp.round(),
    );
    
    Navigator.of(context).pop({
      'name': name,
      'settings': settings,
      'color': _colors[_selectedColorIndex],
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supportsColorTemp = widget.lamps.any((l) => l.supportsColorTemp);

    return AlertDialog(
      title: Text('Neue Szene für ${widget.groupName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Szenenname',
                hintText: 'z.B. Abendlicht',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 24),
            
            // Helligkeit
            Text('Helligkeit: ${_brightness.round()}%',
                 style: theme.textTheme.titleSmall),
            Slider(
              value: _brightness,
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: (value) => setState(() => _brightness = value),
            ),
            
            if (supportsColorTemp) ...[
              const SizedBox(height: 16),
              
              // Farbtemperatur
              Text('Farbtemperatur: ${_colorTemp.round()}K',
                   style: theme.textTheme.titleSmall),
              Slider(
                value: _colorTemp,
                min: 1700,
                max: 6500,
                divisions: 48,
                onChanged: (value) => setState(() => _colorTemp = value),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Farbe
            Text('Szenenfarbe:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.asMap().entries.map((entry) {
                final index = entry.key;
                final color = entry.value;
                final isSelected = index == _selectedColorIndex;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorIndex = index),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 3)
                        : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}

/// Offline-Zustand
class _OfflineState extends StatelessWidget {
  const _OfflineState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Keine Lampen online',
               style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Stelle sicher, dass deine Lampen\nerreichbar sind.',
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Leerer Zustand
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.palette_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Keine Szenen',
               style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Tippe auf + um deine erste\nSzene zu erstellen.',
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}