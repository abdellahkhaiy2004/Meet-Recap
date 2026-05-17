import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/animation_utils.dart';
import '../../domain/entities/folder.dart';

/// Grid card for a folder (architecture §4 + §9, IP-0040).
///
/// Displays a linear gradient derived from [folder.colorHex], an icon, the
/// folder name, and a meeting-count badge. Wrapped in a Hero for shared-element
/// transitions to FolderDetailPage.
///
/// [gridIndex] drives the staggered delay of the idle floating bob animation
/// so cards don't all move in sync.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
    this.gridIndex = 0,
  });

  final Folder folder;
  final VoidCallback onTap;
  final int gridIndex;

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.hexToColor(folder.colorHex);
    final dimColor = baseColor.withAlpha(179); // ≈ 70 % opacity
    final textColor = AppColors.contrastOn(baseColor);
    final animate = animationsEnabled(context);

    final card = Hero(
      tag: 'folder_card_${folder.id}',
      flightShuttleBuilder: _heroShuttle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [baseColor, dimColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withAlpha(77), // 30 %
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Icon ────────────────────────────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51), // 20 %
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForName(folder.iconName),
                      color: textColor,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  // ── Name ────────────────────────────────────────────────
                  Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  // ── Meeting count ────────────────────────────────────────
                  Text(
                    '${folder.meetingCount} réunion${folder.meetingCount != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor.withAlpha(204), // 80 %
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!animate) return card;
    return card
        .animate(
          onPlay: (ctrl) => ctrl.repeat(reverse: true),
          delay: Duration(milliseconds: gridIndex * 220),
        )
        .moveY(
          begin: 0,
          end: -5,
          duration: const Duration(milliseconds: 2200),
          curve: Curves.easeInOut,
        );
  }

  // ── Icon lookup ───────────────────────────────────────────────────────────

  static IconData _iconForName(String name) => switch (name) {
        'inbox'      => Icons.inbox_rounded,
        'briefcase'  => Icons.work_rounded,
        'book'       => Icons.book_rounded,
        'heart'      => Icons.favorite_rounded,
        'activity'   => Icons.show_chart_rounded,
        'dollar'     => Icons.attach_money_rounded,
        'scale'      => Icons.balance_rounded,
        'star'       => Icons.star_rounded,
        'home'       => Icons.home_rounded,
        'mic'        => Icons.mic_rounded,
        'users'      => Icons.group_rounded,
        'calendar'   => Icons.calendar_today_rounded,
        'globe'      => Icons.language_rounded,
        'tag'        => Icons.label_rounded,
        'archive'    => Icons.archive_rounded,
        'graduate'   => Icons.school_rounded,
        'health'     => Icons.local_hospital_rounded,
        'finance'    => Icons.account_balance_rounded,
        _            => Icons.folder_rounded,
      };

  static Widget _heroShuttle(
    BuildContext _,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromCtx,
    BuildContext toCtx,
  ) =>
      FadeTransition(opacity: animation, child: toCtx.widget);
}

/// Returns the icon widget for a given icon-name string.
/// Exported so NewFolderPage's icon-picker can preview the same icons.
IconData folderIconForName(String name) => switch (name) {
      'inbox'     => Icons.inbox_rounded,
      'briefcase' => Icons.work_rounded,
      'book'      => Icons.book_rounded,
      'heart'     => Icons.favorite_rounded,
      'activity'  => Icons.show_chart_rounded,
      'dollar'    => Icons.attach_money_rounded,
      'scale'     => Icons.balance_rounded,
      'star'      => Icons.star_rounded,
      'home'      => Icons.home_rounded,
      'mic'       => Icons.mic_rounded,
      'users'     => Icons.group_rounded,
      'calendar'  => Icons.calendar_today_rounded,
      'globe'     => Icons.language_rounded,
      'tag'       => Icons.label_rounded,
      'archive'   => Icons.archive_rounded,
      'graduate'  => Icons.school_rounded,
      'health'    => Icons.local_hospital_rounded,
      'finance'   => Icons.account_balance_rounded,
      _           => Icons.folder_rounded,
    };

/// All icon-name strings available in the folder icon picker.
const kFolderIconNames = [
  'folder', 'inbox', 'briefcase', 'book', 'heart', 'activity',
  'dollar', 'scale', 'star', 'home', 'mic', 'users',
  'calendar', 'globe', 'tag', 'archive', 'graduate', 'health',
  'finance',
];
