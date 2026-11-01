import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppImageView extends StatelessWidget {
  final String imageSource;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool enableFullScreenOnTap;

  const AppImageView({
    super.key,
    required this.imageSource,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.enableFullScreenOnTap = false,
  });

  /// Opens a full screen modal dialog with pinch-to-zoom interactive viewer
  static void showFullScreen(BuildContext context, String imageSource) {
    if (imageSource.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: AppImageView(
                  imageSource: imageSource,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  tooltip: 'ปิด',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildRawImage();

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (enableFullScreenOnTap && imageSource.trim().isNotEmpty) {
      return GestureDetector(
        onTap: () => showFullScreen(context, imageSource),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildRawImage() {
    final trimmed = imageSource.trim();
    if (trimmed.isEmpty) {
      return _buildPlaceholder();
    }

    // 1. Base64 (data:image/... or long base64 string)
    if (trimmed.startsWith('data:image') || _isLikelyBase64(trimmed)) {
      try {
        final commaIndex = trimmed.indexOf(',');
        final cleanBase64 = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
        final Uint8List bytes = base64Decode(cleanBase64.trim());
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    // 2. Network URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // 3. Local File
    if (!kIsWeb) {
      try {
        final file = File(trimmed);
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    return _buildPlaceholder();
  }

  bool _isLikelyBase64(String str) {
    if (str.length > 200 && !str.contains(' ') && !str.startsWith('/') && !str.contains(':\\')) {
      return true;
    }
    return false;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.grey),
      ),
    );
  }
}
