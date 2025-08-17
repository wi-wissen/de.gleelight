import 'package:flutter/material.dart';
import '../models/lamp.dart';

class LampIcon extends StatelessWidget {
  final Lamp lamp;
  final double size;
  final bool showLabel;
  final VoidCallback? onTap;

  const LampIcon({
    super.key,
    required this.lamp,
    this.size = 48,
    this.showLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget icon = _buildIcon(theme);
    
    if (onTap != null) {
      icon = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: icon,
      );
    }

    if (!showLabel) {
      return icon;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 4),
        SizedBox(
          width: size + 8,
          child: Text(
            lamp.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: lamp.isOffline 
                ? theme.disabledColor
                : theme.colorScheme.onSurfaceVariant,
              fontStyle: lamp.isOffline 
                ? FontStyle.italic 
                : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    // Icon und Farbe basierend auf Status
    IconData iconData;
    Color iconColor;
    Color backgroundColor;
    double opacity;

    switch (lamp.status) {
      case LampStatus.on:
        iconData = Icons.lightbulb;
        iconColor = colorScheme.onPrimary;
        backgroundColor = lamp.iconColor;
        opacity = 1.0;
        break;
        
      case LampStatus.off:
        iconData = Icons.lightbulb_outline;
        iconColor = colorScheme.onSurfaceVariant;
        backgroundColor = colorScheme.surfaceVariant;
        opacity = 0.7;
        break;
        
      case LampStatus.offline:
        iconData = Icons.lightbulb_outline;
        iconColor = colorScheme.outline;
        backgroundColor = colorScheme.surfaceVariant;
        opacity = 0.3;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(opacity),
        shape: BoxShape.circle,
        border: lamp.status == LampStatus.offline
          ? Border.all(
              color: colorScheme.outline.withOpacity(0.3),
              width: 1,
            )
          : null,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: size * 0.5,
      ),
    );
  }
}