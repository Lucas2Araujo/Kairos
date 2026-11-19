import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';
import '../../gamification/monthly_streak_view.dart';
import 'kairos_lamp_mascot.dart';

/// Modal Bottom Sheet expansível de Missões Diárias e Reservatório de Azeite
/// (Inspirado na Parábola das Dez Virgens)
class DailyMissionsBottomSheet extends StatelessWidget {
  const DailyMissionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DailyMissionsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isDark = theme.brightness == Brightness.dark;
    final isGlass = themeService.isAnyGlass;
    final isAscii = themeService.isAscii;
    final isWin95 = themeService.isWin95;
    final isHolo = themeService.isHoloRetro;
    final isSquareRetro = isAscii || isWin95 || isHolo;
    final service = GamificationService();

    const dayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    final sheetContent = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            if (!isAscii && !isWin95)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Cabeçalho com Mascote e Título
            ListenableBuilder(
              listenable: service,
              builder: (context, _) {
                final streak = service.currentStreak;
                final isFull = service.isFullFlameActive;
                final isHalf = service.isHalfStreakActive;

                final streakTitle = isFull
                    ? (isAscii
                        ? 'CHAMA COMPLETA ATIVA (1.5X AZEITE)'
                        : '🔥 Chama Completa Ativa! (1.5x Azeite)')
                    : (isHalf
                        ? (isAscii
                            ? 'MEIA OFENSIVA: CHAMA ACESA'
                            : '✨ Meia Ofensiva: Chama Acesa!')
                        : (streak > 0
                            ? '$streak dias seguidos — Pavio aceso!'
                            : 'Encha sua Lamparina com azeite!'));

                final Widget oilGaugeWidget;
                if (isAscii) {
                  final filledSegments = (service.lampPercentage.clamp(0.0, 1.0) * 10).round();
                  oilGaugeWidget = AsciiBoxSurface(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SnesPixelIcon(
                                  type: SnesPixelIconType.lamp,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    service.isLampFull
                                        ? 'LAMPARINA 100% CHEIA'
                                        : '${service.todayOilDrops}/100 GOTAS HOJE',
                                    style: TextStyle(
                                      fontFamily: 'RetroPixel',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${service.totalOilDrops} GOTAS TOTAIS',
                              style: TextStyle(
                                fontFamily: 'RetroPixel',
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(10, (segIdx) {
                            final active = segIdx < filledSegments;
                            return Expanded(
                              child: Container(
                                height: 12,
                                margin: EdgeInsets.only(right: segIdx < 9 ? 3 : 0),
                                decoration: BoxDecoration(
                                  color: active
                                      ? (service.isLampFull
                                          ? const Color(0xFFFFD54F)
                                          : theme.colorScheme.primary)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.75),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                } else {
                  oilGaugeWidget = Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: isSquareRetro
                          ? BorderRadius.zero
                          : BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  service.isLampFull
                                      ? Icons.lightbulb_rounded
                                      : Icons.opacity_rounded,
                                  color: Colors.amber.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    service.isLampFull
                                        ? 'Lamparina 100% cheia!'
                                        : '${service.todayOilDrops}/100 gotas hoje',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${service.totalOilDrops} gotas totais',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius:
                              isSquareRetro ? BorderRadius.zero : BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: service.lampPercentage,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              service.isLampFull
                                  ? Colors.amber.shade600
                                  : Colors.amber.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        KairosLampMascotWidget(
                          state: service.lampMascotState,
                          oilFill: service.lampPercentage,
                          size: isAscii ? 68 : 64,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAscii
                                    ? 'STATUS DA LAMPARINA'
                                    : 'Reserva de Azeite & Missões',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: isAscii ? 'RetroPixel' : null,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                streakTitle,
                                style: TextStyle(
                                  fontFamily: isAscii ? 'RetroPixel' : null,
                                  fontSize: isAscii ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: isFull
                                      ? Colors.amber.shade700
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(isSquareRetro ? Icons.close_sharp : Icons.close_rounded),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    oilGaugeWidget,
                    const SizedBox(height: 16),

                    // Seção de Missões Diárias
                    Text(
                      isAscii
                          ? 'MISSOES DE HOJE (${service.completedMissionsCount}/4)'
                          : 'Missões de Hoje (${service.completedMissionsCount}/4 cumpridas)',
                      style: TextStyle(
                        fontFamily: isAscii ? 'RetroPixel' : null,
                        fontWeight: FontWeight.bold,
                        fontSize: isAscii ? 13 : 14,
                        color: isAscii ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMissionItem(
                      theme,
                      isAscii: isAscii,
                      isSquareRetro: isSquareRetro,
                      title: 'Tempo com Deus',
                      subtitle:
                          'Fique pelo menos ${service.dailyGoalMinutes} min lendo ou orando (${service.todayFocusMinutes}/${service.dailyGoalMinutes}m)',
                      icon: Icons.hourglass_top_rounded,
                      pixelIcon: SnesPixelIconType.hourglass,
                      isDone: service.mission1TimeWithGod,
                      rewardDrops: 30,
                    ),
                    _buildMissionItem(
                      theme,
                      isAscii: isAscii,
                      isSquareRetro: isSquareRetro,
                      title: 'Palavra Viva',
                      subtitle: 'Leia ao menos 1 capítulo da Bíblia Sagrada',
                      icon: Icons.menu_book_rounded,
                      pixelIcon: SnesPixelIconType.bible,
                      isDone: service.mission2LivingWord,
                      rewardDrops: 40,
                    ),
                    _buildMissionItem(
                      theme,
                      isAscii: isAscii,
                      isSquareRetro: isSquareRetro,
                      title: 'Pão Diário',
                      subtitle: 'Complete a leitura da meditação diária',
                      icon: Icons.wb_sunny_rounded,
                      pixelIcon: SnesPixelIconType.sun,
                      isDone: service.mission3DailyBread,
                      rewardDrops: 30,
                    ),
                    _buildMissionItem(
                      theme,
                      isAscii: isAscii,
                      isSquareRetro: isSquareRetro,
                      title: isAscii ? 'Quiz da Licao' : 'Quiz da Lição ⭐',
                      subtitle: 'Responda as perguntas rápidas da Escola Sabatina',
                      icon: Icons.bolt_rounded,
                      pixelIcon: SnesPixelIconType.bolt,
                      isDone: service.mission4LessonQuiz,
                      rewardDrops: 10,
                    ),
                    const SizedBox(height: 16),

                    // Indicadores compactos da semana
                    Text(
                      isAscii ? 'OFENSIVA DA SEMANA' : 'Ofensiva da Semana',
                      style: TextStyle(
                        fontFamily: isAscii ? 'RetroPixel' : null,
                        fontWeight: FontWeight.bold,
                        fontSize: isAscii ? 13 : 14,
                        color: isAscii ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (index) {
                        final isDone = index < service.weeklyActivity.length &&
                            service.weeklyActivity[index] == true;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dayLabels[index],
                              style: TextStyle(
                                fontFamily: isAscii ? 'RetroPixel' : null,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDone
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: isSquareRetro ? BoxShape.rectangle : BoxShape.circle,
                                color: isDone ? theme.colorScheme.primary : Colors.transparent,
                                border: isDone
                                    ? (isAscii
                                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                                        : null)
                                    : Border.all(
                                        color: isAscii
                                            ? theme.colorScheme.primary.withValues(alpha: 0.45)
                                            : theme.colorScheme.outline.withValues(alpha: 0.35),
                                        width: isAscii ? 2.0 : 1.2,
                                      ),
                              ),
                              child: isDone
                                  ? (isAscii
                                      ? SnesPixelIcon(
                                          type: SnesPixelIconType.check,
                                          size: 16,
                                          color: theme.colorScheme.onPrimary,
                                          accentColor: theme.colorScheme.onPrimary,
                                        )
                                      : Icon(
                                          Icons.check,
                                          size: 16,
                                          color: theme.colorScheme.onPrimary,
                                        ))
                                  : null,
                            ),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Botão para ver o Mês e Conquistas
                    if (isAscii)
                      AsciiBoxSurface(
                        doubleBorder: true,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        onTap: () {
                          Navigator.of(context).pop();
                          MonthlyStreakView.show(context);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SnesPixelIcon(
                              type: SnesPixelIconType.calendar,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '[ VER CALENDARIO DO MES & CONQUISTAS ]',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'RetroPixel',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: const Text('Ver Calendário do Mês & Conquistas'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          MonthlyStreakView.show(context);
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
    );

    if (isAscii) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          10,
          10,
          10,
          MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Center(
          widthFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: AsciiBoxSurface(
              label: 'RESERVA DE AZEITE & MISSOES',
              doubleBorder: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: sheetContent,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Center(
        widthFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            decoration: BoxDecoration(
              color: isGlass
                  ? (isDark ? const Color(0xEB1E1E1E) : const Color(0xF5FFFFFF))
                  : theme.colorScheme.surface,
              borderRadius: isSquareRetro
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isHolo
                    ? const Color(0xFF33B5E5)
                    : theme.dividerColor.withValues(alpha: 0.15),
                width: isHolo ? 1.5 : 1,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: sheetContent,
          ),
        ),
      ),
    );
  }

  Widget _buildMissionItem(
    ThemeData theme, {
    required bool isAscii,
    required bool isSquareRetro,
    required String title,
    required String subtitle,
    required IconData icon,
    required SnesPixelIconType pixelIcon,
    required bool isDone,
    required int rewardDrops,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    final innerRow = Row(
      children: [
        if (isAscii)
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDone
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                width: 2.0,
              ),
            ),
            child: SnesPixelIcon(
              type: isDone ? SnesPixelIconType.check : pixelIcon,
              size: 18,
              color: isDone ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
              accentColor: isDone ? theme.colorScheme.onPrimary : null,
            ),
          )
        else
          CircleAvatar(
            radius: 16,
            backgroundColor: isDone
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              isDone ? Icons.check : icon,
              size: 16,
              color: isDone
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    isAscii ? title.toUpperCase() : title,
                    style: TextStyle(
                      fontFamily: isAscii ? 'RetroPixel' : null,
                      fontWeight: FontWeight.bold,
                      fontSize: isAscii ? 12 : 13,
                      color: isDone ? theme.colorScheme.primary : null,
                    ),
                  ),
                  if (isDone)
                    Text(
                      '+$rewardDrops gotas',
                      style: TextStyle(
                        fontFamily: isAscii ? 'RetroPixel' : null,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: isAscii ? 'RetroPixel' : null,
                  fontSize: isAscii ? 10.5 : 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isAscii) {
      return AsciiBoxSurface(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        doubleBorder: isDone,
        child: innerRow,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDone
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: innerRow,
    );
  }
}
