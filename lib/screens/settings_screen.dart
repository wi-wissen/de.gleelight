import 'package:flutter/material.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../services/yeelight_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final LampGroup group;
  final List<Lamp> lamps;

  const SettingsScreen({
    super.key,
    required this.group,
    required this.lamps,
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
  
  // Farbtemperatur-Presets
  static const List<Map<String, dynamic>> _colorTempPresets = [
    {'name': 'Warm', 'temp': 2700, 'icon': Icons.wb_incandescent},
    {'name': 'Neutral', 'temp': 4000, 'icon': Icons.wb_sunny_outlined},
    {'name': 'Kühl', 'temp': 6500, 'icon': Icons.wb_sunny},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  /// Aktuelle Einstellungen der Gruppe laden
  Future<void> _loadCurrentSettings() async {
    if (widget.lamps.isEmpty) return;
    
    // Durchschnittswerte der Online-Lampen verwenden
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();
    if (onlineLamps.isEmpty) return;
    
    double totalBrightness = 0;
    double totalColorTemp = 0;
    int validColorTempCount = 0;
    
    for (final lamp in onlineLamps) {
      totalBrightness += lamp.brightness;
      if (lamp.colorTemp != null) {
        totalColorTemp += lamp.colorTemp!;
        validColorTempCount++;
      }
    }
    
    setState(() {
      _brightness = totalBrightness / onlineLamps.length;
      if (validColorTempCount > 0) {
        _colorTemp = totalColorTemp / validColorTempCount;
      }
    });
  }

  /// Einstellungen auf alle Lampen anwenden
  Future<void> _applySettings() async {
    if (_isApplying) return;
    
    setState(() => _isApplying = true);
    
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();
    
    for (final lamp in onlineLamps) {
      // Helligkeit setzen
      await _yeelightService.setBrightness(
        lamp.ip, 
        _brightness.round(),
      );
      
      // Farbtemperatur setzen (nur wenn unterstützt)
      if (lamp.supportsColorTemp) {
        await _yeelightService.setColorTemp(
          lamp.ip, 
          _colorTemp.round(),
        );
      }
    }
    
    // Letzte Einstellungen speichern
    await _storage.saveLastSettings(widget.group.id, {
      'brightness': _brightness,
      'colorTemp': _colorTemp,
    });
    
    setState(() => _isApplying = false);
    
    // Erfolgsmeldung
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Einstellungen auf ${onlineLamps.length} ${onlineLamps.length == 1 ? 'Lampe' : 'Lampen'} angewendet',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  /// Farbtemperatur-Preset anwenden
  void _applyColorTempPreset(int temperature) {
    setState(() {
      _colorTemp = temperature.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onlineLamps = widget.lamps.where((l) => !l.isOffline).toList();
    final supportsColorTemp = onlineLamps.any((l) => l.supportsColorTemp);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group.name} - Einstellungen'),
      ),
      
      body: onlineLamps.isEmpty 
        ? const _OfflineState()
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
                            '${onlineLamps.length} ${onlineLamps.length == 1 ? 'Lampe' : 'Lampen'} online',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Helligkeit
                _buildSection(
                  title: 'Helligkeit',
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
                  
                  // Farbtemperatur
                  _buildSection(
                    title: 'Farbtemperatur',
                    icon: Icons.thermostat,
                    child: Column(
                      children: [
                        // Presets
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _colorTempPresets.map((preset) {
                            final isSelected = (_colorTemp - preset['temp']).abs() < 50;
                            return _buildColorTempPreset(
                              preset['name'],
                              preset['temp'],
                              preset['icon'],
                              isSelected,
                              theme,
                            );
                          }).toList(),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Slider
                        Row(
                          children: [
                            const Icon(Icons.wb_incandescent, color: Colors.orange),
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
                
                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isApplying ? null : _applySettings,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isApplying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Anwenden',
                          style: TextStyle(fontSize: 16),
                        ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// Section mit Titel und Icon
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

  /// Farbtemperatur-Preset Button
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
            : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
            ? Border.all(color: theme.colorScheme.primary)
            : null,
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

/// Offline-Zustand wenn keine Lampen online sind
class _OfflineState extends StatelessWidget {
  const _OfflineState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Keine Lampen online',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Stelle sicher, dass deine Lampen\neingeschaltet und erreichbar sind.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}