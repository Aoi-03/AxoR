import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../services/google_drive_service.dart';

/// AxorImage — High-performance, memory-optimized cover art and image widget
///
/// Features:
/// - Limits memory cache (`memCacheWidth: 200, memCacheHeight: 200`) to save RAM & battery
/// - Seamless fallback for local files (`file://` or `/data/...`) and network URLs
/// - Authenticated headers for Google Drive thumbnails
/// - Official AxoR logo display when no artwork exists or on load failure
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
    } else if (url.startsWith('/') ||
        url.startsWith('file://') ||
        RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(url)) {
      // Local file on disk (POSIX or Windows path)
      final filePath = url.startsWith('file://') ? url.substring(7) : url;
      final file = File(filePath);
      if (file.existsSync()) {
        content = Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: 250,
          cacheHeight: 250,
          errorBuilder: (_, _, _) => _defaultPlaceholder(),
        );
      } else {
        content = _defaultPlaceholder();
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      // Remote network image with memory-constrained disk caching
      String resolvedUrl = url;
      if (resolvedUrl.contains('drive.google.com/thumbnail') ||
          resolvedUrl.contains('drive.google.com/uc') ||
          resolvedUrl.contains('drive.google.com/file/d/')) {
        final uri = Uri.tryParse(resolvedUrl);
        String? fileId = uri?.queryParameters['id'];
        if (fileId == null || fileId.isEmpty) {
          final match = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(resolvedUrl);
          fileId = match?.group(1);
        }
        if (fileId != null && fileId.isNotEmpty) {
          resolvedUrl = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
        }
      }

      // googleusercontent.com CDN rejects Bearer tokens with 400/403.
      // Only googleapis.com requires and accepts the Bearer authorization header.
      final needsAuth = resolvedUrl.contains('googleapis.com');
      final headers = needsAuth ? GoogleDriveService().cachedAuthHeaders : null;

      content = CachedNetworkImage(
        imageUrl: resolvedUrl,
        httpHeaders: headers,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: 220,
        memCacheHeight: 220,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, _) =>
            placeholder ?? _shimmerPlaceholder(),
        errorWidget: (_, _, _) =>
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
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated,
            AppColors.surfaceCard,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all((width != null && width! <= 50) ? 6.0 : 12.0),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.music_note_rounded,
              color: AppColors.cyan.withAlpha(140),
              size: (width != null && height != null)
                  ? (width! * 0.45).clamp(16.0, 48.0)
                  : 24.0,
            ),
          ),
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
