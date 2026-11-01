import 'package:flutter/material.dart';
import '../../controllers/quiz_controller.dart';
import '../../models/quiz_question.dart';
import '../../services/gamification_service.dart';

class QuizView extends StatefulWidget {
  final QuizController controller;

  const QuizView({super.key, required this.controller});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  @override
  void initState() {
    super.initState();
    widget.controller.init(showHub: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              ctrl.isViewingHub ? 'Quiz Bíblico' : (ctrl.isRevisionMode ? 'Modo Revisão' : 'Quiz do Dia'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: ctrl.isViewingHub
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar ao Hub',
                    onPressed: () => ctrl.returnToHub(),
                  ),
            actions: [
              ListenableBuilder(
                listenable: GamificationService(),
                builder: (context, _) {
                  final g = GamificationService();
                  final isFull = g.isFullFlameActive;
                  final isHalf = g.isHalfStreakActive;
                  final flameColor = isFull
                      ? Colors.amber.shade700
                      : (isHalf ? Colors.deepOrange : Colors.grey);
                  final flameBg = isFull
                      ? Colors.amber.withValues(alpha: 0.18)
                      : (isHalf
                          ? Colors.deepOrange.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));
                  final flameBorder = isFull
                      ? Colors.amber.withValues(alpha: 0.5)
                      : (isHalf
                          ? Colors.deepOrange.withValues(alpha: 0.3)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.3));

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pill da Ofensiva (Sincronizada com a Home)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: flameBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: flameBorder, width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFull
                                    ? Icons.whatshot_rounded
                                    : (isHalf
                                        ? Icons.local_fire_department_rounded
                                        : Icons.local_fire_department_outlined),
                                color: flameColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${g.currentStreak}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Pill do Azeite / XP (Sincronizada com a Home)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.38), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                g.isLampFull ? Icons.lightbulb_rounded : Icons.opacity_rounded,
                                color: Colors.amber.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${g.totalOilDrops}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: _buildBody(context, ctrl, theme),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, QuizController ctrl, ThemeData theme) {
    if (ctrl.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Tela 1: Hub de Apresentação
    if (ctrl.isViewingHub) {
      return _buildHubView(context, ctrl);
    }

    // Tela 2: Quiz Concluído
    if (ctrl.isCompleted) {
      return Column(
        children: [
          _buildQuizActiveHeader(context, ctrl),
          Expanded(child: _buildCompletionView(context, ctrl)),
        ],
      );
    }

    final question = ctrl.currentQuestion;
    if (question == null) {
      return Column(
        children: [
          _buildQuizActiveHeader(context, ctrl),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhuma pergunta cadastrada para ${ctrl.todayDayTitle}.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Que tal praticar o Modo Revisão com todas as questões da semana?',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => ctrl.returnToHub(),
                          icon: const Icon(Icons.dashboard_rounded, size: 16),
                          label: const Text('Voltar ao Hub'),
                        ),
                        FilledButton.icon(
                          onPressed: () => ctrl.startRevisionQuiz(),
                          icon: const Icon(Icons.history_edu_rounded, size: 16),
                          label: const Text('Iniciar Modo Revisão'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildQuizActiveHeader(context, ctrl),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Barra de progresso
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (ctrl.currentIndex + 1) / ctrl.questions.length,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Contador de perguntas e verse ref
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pergunta ${ctrl.currentIndex + 1} de ${ctrl.questions.length}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (question.verseRef != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Chip(
                              label: Text(
                                '📖 ${question.verseRef}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Texto da pergunta
                    Text(
                      question.question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Alternativas
                    for (int idx = 0; idx < question.options.length; idx++) ...[
                      _buildOptionCard(context, ctrl, question, idx),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),

                    // Feedback pós-resposta
                    if (ctrl.hasSubmitted && ctrl.lastResult != null) ...[
                      _buildFeedbackBox(context, ctrl.lastResult!),
                      const SizedBox(height: 16),
                    ],

                    // Botão de ação (Verificar / Avançar)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: ctrl.selectedOption == null
                          ? null
                          : () {
                              if (!ctrl.hasSubmitted) {
                                ctrl.submitAnswer();
                              } else {
                                ctrl.nextQuestion();
                              }
                            },
                      icon: Icon(ctrl.hasSubmitted ? Icons.arrow_forward : Icons.check),
                      label: Text(
                        ctrl.hasSubmitted
                            ? (ctrl.currentIndex + 1 < ctrl.questions.length ? 'Próxima Pergunta' : 'Concluir Quiz')
                            : 'Verificar Resposta',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHubView(BuildContext context, QuizController ctrl) {
    final theme = Theme.of(context);
    final category = ctrl.currentCategory;
    final isJovens = category.toLowerCase().startsWith('jov');
    final lessonTitle = isJovens ? 'Lição dos Jovens' : 'Lição dos Adultos';
    final lessonSubtitle = isJovens
        ? 'Conteúdo dinâmico com foco na juventude'
        : 'Estudo aprofundado da Escola Sabatina';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card da Lição Selecionada no Topo (Fixa pelo perfil)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isJovens ? Icons.bolt_rounded : Icons.menu_book_rounded,
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                lessonTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isJovens ? 'JOVENS' : 'ADULTOS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            lessonSubtitle,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Escolha o Modo do Desafio',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 14),

              // Card 1: Quiz do Dia
              _buildModeCard(
                context,
                title: 'Quiz de ${ctrl.todayDayTitle}',
                subtitle: 'Perguntas específicas da lição do dia de hoje para fixação imediata.',
                badgeText: '${ctrl.todayQuestionsCount} perguntas',
                icon: Icons.calendar_today_rounded,
                iconColor: Colors.blueAccent,
                buttonText: 'Iniciar Quiz do Dia',
                isPrimary: true,
                onTap: () => ctrl.startDailyQuiz(),
              ),
              const SizedBox(height: 16),

              // Card 2: Modo Revisão
              _buildModeCard(
                context,
                title: 'Modo Revisão Semanal',
                subtitle: 'Todas as questões da semana desde Sábado até o dia atual.',
                badgeText: '${ctrl.revisionQuestionsCount} perguntas acumuladas',
                icon: Icons.history_edu_rounded,
                iconColor: Colors.amber.shade700,
                buttonText: 'Iniciar Modo Revisão',
                isPrimary: false,
                onTap: () => ctrl.startRevisionQuiz(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color iconColor,
    required String buttonText,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: isPrimary ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: isPrimary
                  ? FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(buttonText),
                    )
                  : OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(buttonText),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizActiveHeader(BuildContext context, QuizController ctrl) {
    final theme = Theme.of(context);
    final isRev = ctrl.isRevisionMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isRev ? Icons.history_edu_rounded : Icons.calendar_today_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRev ? 'Modo Revisão (Semana)' : 'Quiz de ${ctrl.todayDayTitle}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.dashboard_rounded, size: 16),
                label: const Text('Hub', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => ctrl.returnToHub(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    QuizController ctrl,
    QuizQuestion q,
    int idx,
  ) {
    final theme = Theme.of(context);
    final isSelected = ctrl.selectedOption == idx;
    final isSubmitted = ctrl.hasSubmitted;
    final isCorrectOption = idx == q.correctOption;

    Color borderColor = theme.colorScheme.outlineVariant;
    Color bgColor = theme.cardColor;

    if (isSubmitted) {
      if (isCorrectOption) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.12);
      } else if (isSelected && !isCorrectOption) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.12);
      }
    } else if (isSelected) {
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.08);
    }

    return InkWell(
      onTap: isSubmitted ? null : () => ctrl.selectOption(idx),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: borderColor.withValues(alpha: 0.2),
              child: Text(
                String.fromCharCode(65 + idx),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSubmitted && isCorrectOption
                      ? Colors.green
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                q.options[idx],
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBox(BuildContext context, QuizResult res) {
    final isCorrect = res.isCorrect;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCorrect ? Colors.green : Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correto! (+10 XP)' : 'Incorreto!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (res.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              res.explanation,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, QuizController ctrl) {
    final theme = Theme.of(context);
    final total = ctrl.questions.length;
    final score = ctrl.score;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Parabéns!',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                ctrl.isRevisionMode
                    ? 'Você acertou $score de $total questões na revisão semanal!'
                    : 'Você acertou $score de $total questões do quiz!',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatBadge('XP Ganho', '+${ctrl.totalXp}', Colors.green),
                  const SizedBox(width: 16),
                  _buildStatBadge('Ofensiva', '🔥 ${ctrl.streak}', Colors.orange),
                ],
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ctrl.restart(),
                    icon: const Icon(Icons.replay),
                    label: const Text('Refazer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => ctrl.returnToHub(),
                    icon: const Icon(Icons.dashboard_rounded),
                    label: const Text('Voltar ao Hub'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            val,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
