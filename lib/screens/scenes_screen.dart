import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _scenes = [...widget.scenes];
    _addDefaultScenesIfEmpty();
  }

  /// Add default scenes if none exist
  void _addDefaultScenesIfEmpty() async {
    if (_scenes.isEmpty) {
      final l10n = AppLocalizations.of(context);
      final defaultScenes = [
        Scene(
          id: 'warm_${DateTime.now().millisecondsSinceEpoch}',
          name: l10n?.warm ?? 'Warm',
          settings: SceneSettings.warm,
          iconColor: const Color(0xFFFF9800),
        ),
        Scene(
          id: 'bright_${DateTime.now().millisecondsSinceEpoch + 1}',
          name: l10n?.bright ?? 'Bright',
          settings: SceneSettings.bright,
          iconColor: const Color(0xFF2196F3),
        ),
        Scene(
          id: 'dim_${DateTime.now().millisecondsSinceEpoch + 2}',
          name: l10n?.dimmed ?? 'Dimmed',
          settings: SceneSettings.dim,
          iconColor: const Color(0xFF9C27B0),
        ),
      ];

      setState(() {
        _scenes = defaultScenes;
        _hasChanges = true;
      });

      // Save default scenes
      for (final scene in defaultScenes) {
        await _storage.updateScene(scene);
      }
    }
  }

  /// Apply scene
  Future<void> _applyScene(Scene scene) async {
    if (_isApplying) return;

    setState(() => _isApplying = true);

    await Future.wait(
        widget.lamps.map((lamp) => _applySceneToLamp(scene, lamp)));

    if (mounted) setState(() => _isApplying = false);

    // Success message
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sceneApplied(scene.name)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  /// Apply a scene to one lamp.
  ///
  /// `set_scene` puts the lamp into the target state in a single command and is
  /// accepted whether the lamp is on or off (spec 4.1), so an off lamp does not
  /// need a separate set_power first.
  Future<void> _applySceneToLamp(Scene scene, Lamp lamp) async {
    final brightness = scene.settings.brightness.clamp(1, 100);

    switch (scene.settings.type) {
      case SceneType.colorTemp:
        if (scene.settings.colorTemp != null && lamp.supportsColorTemp) {
          await _yeelightService.setScene(
            lamp.ip,
            'ct',
            [scene.settings.colorTemp!.clamp(1700, 6500), brightness],
          );
          return;
        }
        break;

      case SceneType.rgb:
        if (scene.settings.rgb != null && lamp.supportsRgb) {
          await _yeelightService.setScene(
            lamp.ip,
            'color',
            [scene.settings.rgb!.clamp(0, 16777215), brightness],
          );
          return;
        }
        break;

      case SceneType.brightness:
        break;
    }

    // Brightness-only scene, or a lamp that does not support the scene's colour
    // mode: turn it on at the requested brightness and leave the rest alone.
    if (!lamp.power) {
      await _yeelightService.setPower(lamp.ip, true);
    }
    await _yeelightService.setBrightness(lamp.ip, brightness);
  }

  /// Delete scene
  Future<void> _deleteScene(Scene scene) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteSceneTitle),
        content: Text(l10n.deleteSceneConfirm(scene.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _scenes.removeWhere((s) => s.id == scene.id);
        _hasChanges = true;
      });

      await _storage.deleteScene(scene.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_hasChanges) {
          Navigator.of(context).pop('scenes_changed');
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.groupScenes(widget.group.name)),
        ),
        body: onlineLamps.isEmpty
            ? const OfflineState()
            : _scenes.isEmpty
                ? const EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _scenes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final scene = _scenes[index];
                      return SceneCard(
                        scene: scene,
                        isApplying: _isApplying,
                        onApply: () => _applyScene(scene),
                        onDelete: () => _deleteScene(scene),
                      );
                    },
                  ),
      ),
    );
  }
}

/// Scene card
class SceneCard extends StatelessWidget {
  final Scene scene;
  final bool isApplying;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  const SceneCard({
    super.key,
    required this.scene,
    required this.isApplying,
    required this.onApply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  color: scene.iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.palette,
                  color: scene.iconColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Name and description
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
                      scene.settings.getLocalizedDescription(l10n),
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
                tooltip: l10n.delete,
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

/// Offline state
class OfflineState extends StatelessWidget {
  const OfflineState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(l10n.noLampsOnline,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(l10n.ensureLampsReachable,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// Empty state
class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.palette_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(l10n.noScenes,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(l10n.scenesAutoCreated,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
