import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/gamification_service.dart';
import '../profile/avatar_builder_modal.dart';
import 'monthly_streak_view.dart';

/// Gerencia o banner celebratório flutuante quando uma nova conquista ou item
/// de Avatar especial é desbloqueado em qualquer tela do Kairós.
class AchievementUnlockBanner {
  static bool _attached = false;

  static void attach() {
    if (_attached) return;
    _attached = true;
    GamificationService().onAchievementUnlocked = _showUnlockSnackBar;
  }

  static void _showUnlockSnackBar(AchievementDefinition achievement) {
    final messenger = KairosWebApp.scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: achievement.color.withValues(alpha: 0.22),
                border: Border.all(
                  color: achievement.color.withValues(alpha: 0.65),
                  width: 1.5,
                ),
              ),
              child: Icon(
                achievement.icon,
                color: achievement.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conquista Desbloqueada!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: achievement.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (achievement.rewardLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🎁 ${achievement.rewardLabel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: achievement.rewardLabel != null ? 'Equipar' : 'Ver',
          textColor: Colors.amberAccent,
          onPressed: () {
            final ctx = KairosWebApp.navigatorKey.currentContext;
            if (ctx == null) return;
            if (achievement.rewardLabel != null) {
              AvatarBuilderModal.show(ctx);
            } else {
              MonthlyStreakView.show(ctx);
            }
          },
        ),
      ),
    );
  }
}
