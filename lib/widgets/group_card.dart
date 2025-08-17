import 'package:flutter/material.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import 'lamp_icon.dart';

class GroupCard extends StatelessWidget {
  final LampGroup group;
  final List<Lamp> lamps;
  final VoidCallback onToggle;
  final VoidCallback onSettings;
  final VoidCallback onScenes;

  const GroupCard({
    super.key,
    required this.group,
    required this.lamps,
    required this.onToggle,
    required this.onSettings,
    required this.onScenes,
  });

  @override
  Widget build(BuildContext context) {
    final status = GroupStatus.fromLamps(lamps);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mit Titel und Status
              Row(
                children: [
                  // Haupt-Icon
                  _buildMainIcon(status, colorScheme),
                  const SizedBox(width: 12),
                  
                  // Titel und Status-Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: status.hasOnlineLamps 
                              ? null 
                              : theme.disabledColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getStatusText(status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: status.hasOnlineLamps 
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.disabledColor,
                            fontStyle: status.hasOnlineLamps 
                              ? FontStyle.normal 
                              : FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scenes Button
                      IconButton(
                        onPressed: status.hasOnlineLamps ? onScenes : null,
                        icon: const Icon(Icons.palette_outlined),
                        tooltip: 'Szenen',
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                      
                      // Settings Button  
                      IconButton(
                        onPressed: status.hasOnlineLamps ? onSettings : null,
                        icon: const Icon(Icons.tune),
                        tooltip: 'Einstellungen',
                        style: IconButton.styleFrom(
                          foregroundColor: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Lampen-Icons (nur bei mehr als einer Lampe)
              if (lamps.length > 1) ...[
                const SizedBox(height: 12),
                _buildLampIcons(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Haupt-Icon basierend auf Gruppenstatus
  Widget _buildMainIcon(GroupStatus status, ColorScheme colorScheme) {
    Color iconColor;
    IconData iconData;
    
    switch (status.primaryStatus) {
      case LampStatus.on:
        iconColor = status.isMixed 
          ? colorScheme.primary.withOpacity(0.7)
          : colorScheme.primary;
        iconData = Icons.lightbulb;
        break;
      case LampStatus.off:
        iconColor = colorScheme.outline;
        iconData = Icons.lightbulb_outline;
        break;
      case LampStatus.offline:
        iconColor = colorScheme.outline.withOpacity(0.5);
        iconData = Icons.lightbulb_outline;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: group.iconColor.withOpacity(
          status.hasOnlineLamps ? 0.15 : 0.05,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  /// Status-Text generieren
  String _getStatusText(GroupStatus status) {
    if (!status.hasOnlineLamps) {
      return 'Offline';
    }
    
    if (lamps.length == 1) {
      return status.allOn ? 'An' : 'Aus';
    }
    
    if (status.allOn) {
      return 'Alle an (${status.onlineCount})';
    } else if (status.allOff) {
      return 'Alle aus (${status.onlineCount})';
    } else {
      final onCount = lamps.where((l) => !l.isOffline && l.power).length;
      return '$onCount von ${status.onlineCount} an';
    }
  }

  /// Kleine Lampen-Icons für Multi-Lampen-Gruppen
  Widget _buildLampIcons(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: lamps.take(6).map((lamp) {
        return LampIcon(
          lamp: lamp,
          size: 32,
          showLabel: false,
        );
      }).toList(),
    );
  }
}