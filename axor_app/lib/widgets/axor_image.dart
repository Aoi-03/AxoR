import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';

/// AxorImage — High-performance, memory-optimized cover art and image widget
///
/// Features:
/// - Limits memory cache (`memCacheWidth: 200, memCacheHeight: 200`) to save RAM
/// - Seamless fallback for local files (`file://` or `/data/...`) and network URLs
/// - Disk caching via CachedNetworkImage
/// - Cyberpunk stylized fallback when no cover exists
class AxorImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AxorImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(8);

    Widget content;
    final url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      content = _defaultPlaceholder();
    } else if (url.startsWith('/') || url.startsWith('file://')) {
      // Local file on disk
      final filePath = url.startsWith('file://') ? url.substring(7) : url;
      final file = File(filePath);
      if (file.existsSync()) {
        content = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: 300,
          cacheHeight: 300,
          errorBuilder: (_, __, ___) => _defaultPlaceholder(),
        );
      } else {
        content = _defaultPlaceholder();
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      // Remote network image with memory-constrained disk caching
      content = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: 250,
        memCacheHeight: 250,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) =>
            placeholder ?? _shimmerPlaceholder(),
        errorWidget: (_, __, ___) =>
            errorWidget ?? _defaultPlaceholder(),
      );
    } else {
      content = _defaultPlaceholder();
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: content,
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: AppColors.cyan.withAlpha(140),
          size: (width != null && height != null) ? (width! * 0.45).clamp(16.0, 48.0) : 24.0,
        ),
      ),
    );
  }

  Widget _shimmerPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceElevated,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withAlpha(120),
          ),
        ),
      ),
    );
  }
}
