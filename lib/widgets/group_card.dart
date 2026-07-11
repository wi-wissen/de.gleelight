import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/lamp.dart';
import '../models/group.dart';
import '../models/scene.dart';
import 'lamp_icon.dart';

class GroupCard extends StatelessWidget {
  final LampGroup group;
  final List<Lamp> lamps;
  final Scene? activeScene;
  final VoidCallback onToggle;
  final VoidCallback onSettings;
  final VoidCallback onScenes;
  final VoidCallback? onDelete;
  final VoidCallback? onLampSettings;

  const GroupCard({
    super.key,
    required this.group,
    required this.lamps,
    this.activeScene,
    required this.onToggle,
    required this.onSettings,
    required this.onScenes,
    this.onDelete,
    this.onLampSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              // Header with title and status
              _buildHeader(context, status, theme, colorScheme, l10n),

              // Lamp icons (only for more than one lamp)
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

  /// Display name without IP address
  String _getDisplayName(AppLocalizations l10n) {
    if (group.type == GroupType.all) {
      return l10n.all;
    }
    if (group.type == GroupType.single && lamps.isNotEmpty) {
      final lamp = lamps.first;
      // Remove IP address from name if present
      final name = lamp.name;
      final ipPattern = RegExp(r'\s*\(?\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\)?');
      return name.replaceAll(ipPattern, '').trim();
    }
    return group.name;
  }

  /// Subtitle text with status (without IP)
  String _getSubtitleText(GroupStatus status, AppLocalizations l10n) {
    if (!status.hasOnlineLamps) {
      return l10n.offline;
    }

    if (group.type == GroupType.single || lamps.length == 1) {
      return status.allOn ? l10n.on : l10n.off;
    }

    if (status.allOn) {
      return l10n.allOn(status.onlineCount);
    } else if (status.allOff) {
      return l10n.allOff(status.onlineCount);
    } else {
      final onCount = lamps.where((l) => !l.isOffline && l.power).length;
      return l10n.someOn(onCount, status.onlineCount);
    }
  }

  /// Build the header with title, status, scene badge, and IP
  Widget _buildHeader(BuildContext context, GroupStatus status, ThemeData theme,
      ColorScheme colorScheme, AppLocalizations l10n) {
    return Row(
      children: [
        // Main icon
        _buildMainIcon(status, colorScheme),
        const SizedBox(width: 12),

        // Title, status text, and IP
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getDisplayName(l10n),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: status.hasOnlineLamps ? null : theme.disabledColor,
                ),
              ),
              const SizedBox(height: 2),
              // Status and Scene Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _getSubtitleText(status, l10n),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status.hasOnlineLamps
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.disabledColor,
                        fontStyle: status.hasOnlineLamps
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (activeScene != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.palette,
                            size: 12,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            activeScene!.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              // IP Address in third line (only for single lamps)
              if (group.type == GroupType.single && lamps.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  lamps.first.ip,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Action Buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scenes Button
            IconButton(
              onPressed: onScenes,
              icon: const Icon(Icons.palette_outlined),
              tooltip: l10n.scenes,
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
            ),

            // Settings Button
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.tune),
              tooltip: l10n.settings,
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
            ),

            // Popup Menu for single lamps and custom groups
            if (group.type != GroupType.all &&
                (onLampSettings != null || onDelete != null))
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.moreOptions,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onLampSettings?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  // Edit only for single lamps
                  if (group.type == GroupType.single && onLampSettings != null)
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(l10n.edit),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  // Delete for single lamps and custom groups
                  if (onDelete != null)
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: colorScheme.error),
                        title: Text(
                          group.type == GroupType.single
                              ? l10n.deleteLamp
                              : l10n.deleteGroup,
                          style: TextStyle(color: colorScheme.error),
                        ),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// Main icon based on group status
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
        color: status.hasOnlineLamps
            ? group.iconColor.withOpacity(0.2)
            : Colors.grey.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  /// Small lamp icons for multi-lamp groups
  Widget _buildLampIcons(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: lamps.take(6).map((lamp) {
        return LampIcon(
          lamp: lamp,
          size: 32,
          showLabel: false,
          isSmallIcon: true,
        );
      }).toList(),
    );
  }
}
