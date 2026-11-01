import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? imageSource;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;

  const UserAvatar({
    super.key,
    required this.imageSource,
    this.radius = 24,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.mocha.withValues(alpha: 0.15);
    final iColor = iconColor ?? AppTheme.mocha;

    if (imageSource == null || imageSource!.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Icon(fallbackIcon, color: iColor, size: radius * 1.1),
      );
    }

    final trimmed = imageSource!.trim();

    try {
      if (trimmed.startsWith('data:image')) {
        final commaIndex = trimmed.indexOf(',');
        final base64String = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
        final bytes = base64Decode(base64String);
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: MemoryImage(bytes),
        );
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: NetworkImage(trimmed),
          onBackgroundImageError: (_, _) {},
        );
      } else if (!kIsWeb && File(trimmed).existsSync()) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: FileImage(File(trimmed)),
        );
      } else {
        // Fallback: try decoding as plain base64
        final bytes = base64Decode(trimmed);
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: MemoryImage(bytes),
        );
      }
    } catch (_) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Icon(fallbackIcon, color: iColor, size: radius * 1.1),
      );
    }
  }
}
