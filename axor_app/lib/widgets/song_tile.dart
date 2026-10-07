import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';

/// Premium song list tile with album art, metadata, and action buttons
class SongTile extends StatelessWidget {
  final String title;
  final String artist;
  final String? albumArtUrl;
  final String? duration;
  final bool isPlaying;
  final bool isCurrentSong;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.title,
    required this.artist,
    this.albumArtUrl,
    this.duration,
    this.isPlaying = false,
    this.isCurrentSong = false,
    this.index,
    this.onTap,
    this.onMoreTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primary.withAlpha(15),
        highlightColor: AppColors.primary.withAlpha(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isCurrentSong
                ? AppColors.primary.withAlpha(15)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // Index or playing indicator
              if (index != null)
                SizedBox(
                  width: 28,
                  child: Center(
                    child: isCurrentSong
                        ? _PlayingIndicator(isAnimating: isPlaying)
                        : Text(
                            '${index! + 1}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                ),
              if (index != null) const SizedBox(width: 12),

              // Album Art
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.surfaceCard,
                  boxShadow: isCurrentSong
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(40),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: albumArtUrl != null && albumArtUrl!.startsWith('http')
                      ? Image.network(
                          albumArtUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultArt(),
                        )
                      : _defaultArt(),
                ),
              ),
              const SizedBox(width: 14),

              // Song Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: isCurrentSong
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isCurrentSong
                            ? AppColors.primary.withAlpha(180)
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Duration
              if (duration != null) ...[
                const SizedBox(width: 8),
                Text(
                  duration!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],

              // Trailing widget or more button
              if (trailing != null)
                trailing!
              else if (onMoreTap != null)
                IconButton(
                  onPressed: onMoreTap,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultArt() {
    return Container(
      color: AppColors.surfaceCard,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: isCurrentSong ? AppColors.primary : AppColors.textTertiary,
          size: 22,
        ),
      ),
    );
  }
}

/// Animated equalizer bars for currently playing indicator
class _PlayingIndicator extends StatefulWidget {
  final bool isAnimating;

  const _PlayingIndicator({this.isAnimating = true});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: Duration(milliseconds: 400 + i * 150),
        vsync: this,
      );
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isAnimating) {
      for (var c in _controllers) {
        c.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(_PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      for (var c in _controllers) {
        c.repeat(reverse: true);
      }
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      for (var c in _controllers) {
        c.stop();
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Container(
              width: 3,
              height: 14 * _animations[i].value,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          },
        );
      }),
    );
  }
}
