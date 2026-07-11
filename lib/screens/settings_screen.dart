import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';
import '../services/yeelight_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final LampGroup group;
  final List<Lamp> lamps;
  final Function(Scene) onSceneSaved;

  const SettingsScreen({
    super.key,
    required this.group,
    required this.lamps,
    required this.onSceneSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final YeelightService _yeelightService = YeelightService();
  final StorageService _storage = StorageService.instance;

  double _brightness = 100;
  double _colorTemp = 4000;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  /// Load current group settings
  Future<void> _loadCurrentSettings() async {
    if (widget.lamps.isEmpty) return;

    // Use average values of all lamps (try to load from offline ones too)
    final lampsWithData = widget.lamps;
    if (lampsWithData.isEmpty) return;

    double totalBrightness = 0;
    double totalColorTemp = 0;
    int validColorTempCount = 0;

    for (final lamp in lampsWithData) {
      totalBrightness += lamp.brightness;
      if (lamp.colorTemp != null) {
        totalColorTemp += lamp.colorTemp!;
        validColorTempCount++;
      }
    }

    setState(() {
      _brightness = totalBrightness / lampsWithData.length;
      if (validColorTempCount > 0) {
        _colorTemp = totalColorTemp / validColorTempCount;
      }
    });
  }

  /// Apply settings to all lamps
  Future<void> _applySettings() async {
    if (_isApplying) return;

    setState(() => _isApplying = true);

    await Future.wait(widget.lamps.map((lamp) async {
      await _yeelightService.setBrightness(
        lamp.ip,
        _brightness.round(),
        isOn: lamp.power,
      );

      if (lamp.supportsColorTemp) {
        await _yeelightService.setColorTemp(
          lamp.ip,
          _colorTemp.round(),
          isOn: lamp.power,
          brightness: _brightness.round(),
        );
      }
    }));

    // Save last settings
    await _storage.saveLastSettings(widget.group.id, {
      'brightness': _brightness,
      'colorTemp': _colorTemp,
    });

    if (mounted) setState(() => _isApplying = false);
  }

  /// Save current settings as new scene
  Future<void> _saveAsScene() async {
    final l10n = AppLocalizations.of(context)!;

    final sceneName = await showDialog<String>(
      context: context,
      builder: (context) => const SaveSceneDialog(),
    );

    if (sceneName != null && sceneName.trim().isNotEmpty) {
      setState(() => _isApplying = true);

      // First apply the settings
      await _applySettings();

      // Then save as scene
      final scene = Scene(
        id: 'scene_${DateTime.now().millisecondsSinceEpoch}',
        name: sceneName.trim(),
        settings: SceneSettings.colorTemp(
          brightness: _brightness.round(),
          colorTemp: _colorTemp.round(),
        ),
        iconColor: const Color(0xFFFF9800), // Orange for new scenes
      );

      await _storage.updateScene(scene);

      // Call callback to notify HomeScreen
      widget.onSceneSaved(scene);

      setState(() => _isApplying = false);

      // Success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sceneSaved(sceneName)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: l10n.showScenes,
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).pop(), // Back to main page
            ),
          ),
        );
      }
    }
  }

  /// Apply color temperature preset
  void _applyColorTempPreset(int temperature) {
    setState(() {
      _colorTemp = temperature.toDouble();
    });
    // Apply immediately
    _applyColorTempOnly(temperature);
  }

  /// Apply brightness only (for real-time updates)
  Future<void> _applyBrightnessOnly(int brightness) async {
    await Future.wait(widget.lamps.map(
      (lamp) => _yeelightService.setBrightness(
        lamp.ip,
        brightness,
        isOn: lamp.power,
      ),
    ));
  }

  /// Apply color temperature only (for real-time updates)
  Future<void> _applyColorTempOnly(int colorTemp) async {
    await Future.wait(widget.lamps.where((l) => l.supportsColorTemp).map(
          (lamp) => _yeelightService.setColorTemp(
            lamp.ip,
            colorTemp,
            isOn: lamp.power,
            brightness: _brightness.round(),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final allLamps = widget.lamps;
    final supportsColorTemp = allLamps.any((l) => l.supportsColorTemp);

    // Color temperature presets with localized names
    final colorTempPresets = [
      {'name': l10n.warm, 'temp': 2700, 'icon': Icons.wb_incandescent},
      {'name': l10n.neutral, 'temp': 4000, 'icon': Icons.wb_sunny_outlined},
      {'name': l10n.cool, 'temp': 6500, 'icon': Icons.wb_sunny},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupSettings(widget.group.name)),
      ),
      body: allLamps.isEmpty
          ? const OfflineState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.lampsOnline(allLamps.length),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Brightness
                  _buildSection(
                    title: l10n.brightness,
                    icon: Icons.brightness_6,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.brightness_low),
                            Expanded(
                              child: Slider(
                                value: _brightness,
                                min: 1,
                                max: 100,
                                divisions: 99,
                                label: '${_brightness.round()}%',
                                onChanged: (value) {
                                  setState(() => _brightness = value);
                                },
                                onChangeEnd: (value) {
                                  // Real-time update on release
                                  _applyBrightnessOnly(value.round());
                                },
                              ),
                            ),
                            const Icon(Icons.brightness_high),
                          ],
                        ),
                        Text(
                          '${_brightness.round()}%',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (supportsColorTemp) ...[
                    const SizedBox(height: 24),

                    // Color Temperature
                    _buildSection(
                      title: l10n.colorTemperature,
                      icon: Icons.thermostat,
                      child: Column(
                        children: [
                          // Presets
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: colorTempPresets.map((preset) {
                              final isSelected =
                                  (_colorTemp - (preset['temp'] as int)).abs() <
                                      50;
                              return _buildColorTempPreset(
                                preset['name'] as String,
                                preset['temp'] as int,
                                preset['icon'] as IconData,
                                isSelected,
                                theme,
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 16),

                          // Slider
                          Row(
                            children: [
                              const Icon(Icons.wb_incandescent,
                                  color: Colors.orange),
                              Expanded(
                                child: Slider(
                                  value: _colorTemp,
                                  min: 1700,
                                  max: 6500,
                                  divisions: 48,
                                  label: '${_colorTemp.round()}K',
                                  onChanged: (value) {
                                    setState(() => _colorTemp = value);
                                  },
                                  onChangeEnd: (value) {
                                    // Real-time update on release
                                    _applyColorTempOnly(value.round());
                                  },
                                ),
                              ),
                              const Icon(Icons.wb_sunny, color: Colors.blue),
                            ],
                          ),

                          Text(
                            '${_colorTemp.round()}K',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Save as Scene Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isApplying ? null : _saveAsScene,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.palette),
                      label: _isApplying
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              l10n.saveAsScene,
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Section with title and icon
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  /// Color temperature preset button
  Widget _buildColorTempPreset(
    String name,
    int temp,
    IconData icon,
    bool isSelected,
    ThemeData theme,
  ) {
    return GestureDetector(
      onTap: () => _applyColorTempPreset(temp),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected ? Border.all(color: theme.colorScheme.primary) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to save a scene
class SaveSceneDialog extends StatefulWidget {
  const SaveSceneDialog({super.key});

  @override
  State<SaveSceneDialog> createState() => _SaveSceneDialogState();
}

class _SaveSceneDialogState extends State<SaveSceneDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.saveScene),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: l10n.sceneName,
          hintText: l10n.sceneNameHint,
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop(name);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Offline state when no lamps are online
class OfflineState extends StatelessWidget {
  const OfflineState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noLampsOnline,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.ensureLampsOn,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
