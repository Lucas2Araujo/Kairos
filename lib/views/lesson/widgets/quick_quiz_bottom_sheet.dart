import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../controllers/quiz_controller.dart';
import '../../../data/repositories/quiz_repository.dart';
import '../../../models/quiz_question.dart';
import '../../../services/theme_service.dart';

/// Bottom sheet responsivo para o desafio rápido de fixação da lição da Escola Sabatina.
class QuickQuizBottomSheet extends StatefulWidget {
  final String category;
  final String dayId;
  final QuizRepository? quizRepository;
  final QuizController? quizController;

  const QuickQuizBottomSheet({
    super.key,
    required this.category,
    required this.dayId,
    this.quizRepository,
    this.quizController,
  });

  static Future<void> show(
    BuildContext context, {
    required String category,
    required String dayId,
    QuizRepository? quizRepository,
    QuizController? quizController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickQuizBottomSheet(
        category: category,
        dayId: dayId,
        quizRepository: quizRepository,
        quizController: quizController,
      ),
    );
  }

  @override
  State<QuickQuizBottomSheet> createState() => _QuickQuizBottomSheetState();
}

class _QuickQuizBottomSheetState extends State<QuickQuizBottomSheet> {
  late final QuizController _ctrl;
  late final bool _isLocalController;

  @override
  void initState() {
    super.initState();
    if (widget.quizController != null) {
      _ctrl = widget.quizController!;
      _isLocalController = false;
    } else {
      _ctrl = QuizController(repository: widget.quizRepository);
      _isLocalController = true;
    }

    _ctrl.init(
      category: widget.category,
      dayId: _resolveDayId(widget.dayId),
      mode: 'diario',
    );
  }

  @override
  void dispose() {
    if (_isLocalController) {
      _ctrl.dispose();
    }
    super.dispose();
  }

  static String _resolveDayId(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean.startsWith('d') && clean.length == 2) return clean;
    final match = RegExp(r'(\d+)$').firstMatch(clean);
    if (match != null) {
      final num = int.tryParse(match.group(1)!);
      if (num != null && num >= 1 && num <= 7) {
        return 'd$num';
      }
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    Widget content = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              // Barra de arraste
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabeçalho com Ofensiva, XP e Botão Fechar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bolt,
                            size: 18,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Desafio da Lição',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                            const SizedBox(width: 3),
                            Text(
                              '${_ctrl.streak}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.stars, color: Colors.amber, size: 20),
                            const SizedBox(width: 3),
                            Text(
                              '${_ctrl.totalXp} XP',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              // Corpo do Quiz
              Expanded(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    if (_ctrl.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_ctrl.isCompleted) {
                      return _buildCompletionView(context, theme);
                    }

                    final question = _ctrl.currentQuestion;
                    if (question == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.quiz_outlined, size: 48, color: theme.colorScheme.outline),
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhuma pergunta disponível para esta lição hoje.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Barra de progresso
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (_ctrl.currentIndex + 1) / _ctrl.questions.length,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Contador de perguntas e verseRef
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pergunta ${_ctrl.currentIndex + 1} de ${_ctrl.questions.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (question.verseRef != null)
                                Chip(
                                  label: Text(
                                    '📖 ${question.verseRef}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Pergunta
                          Text(
                            question.question,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Alternativas
                          for (int idx = 0; idx < question.options.length; idx++) ...[
                            _buildOptionCard(context, theme, question, idx),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 8),

                          // Feedback pós-resposta
                          if (_ctrl.hasSubmitted && _ctrl.lastResult != null) ...[
                            _buildFeedbackBox(context, _ctrl.lastResult!),
                            const SizedBox(height: 14),
                          ],

                          // Botão de Ação
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _ctrl.selectedOption == null
                                ? null
                                : () {
                                    if (!_ctrl.hasSubmitted) {
                                      _ctrl.submitAnswer();
                                    } else {
                                      _ctrl.nextQuestion();
                                    }
                                  },
                            icon: Icon(_ctrl.hasSubmitted ? Icons.arrow_forward : Icons.check, size: 18),
                            label: Text(
                              _ctrl.hasSubmitted
                                  ? (_ctrl.currentIndex + 1 < _ctrl.questions.length
                                      ? 'Próxima Pergunta'
                                      : 'Concluir Desafio')
                                  : 'Verificar Resposta',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        if (ThemeService().isAnyGlass && ThemeService().glassBlurEnabled) {
          content = ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: content,
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 680, maxHeight: maxHeight),
            child: content,
          ),
        );
      }

  Widget _buildOptionCard(
    BuildContext context,
    ThemeData theme,
    QuizQuestion q,
    int idx,
  ) {
    final isSelected = _ctrl.selectedOption == idx;
    final isSubmitted = _ctrl.hasSubmitted;
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
      onTap: isSubmitted ? null : () => _ctrl.selectOption(idx),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: borderColor.withValues(alpha: 0.2),
              child: Text(
                String.fromCharCode(65 + idx),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSubmitted && isCorrectOption
                      ? Colors.green
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                q.options[idx],
                style: const TextStyle(fontSize: 14),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
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
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect ? 'Correto! (+10 XP)' : 'Incorreto!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (res.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              res.explanation,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, ThemeData theme) {
    final total = _ctrl.questions.length;
    final score = _ctrl.score;
    final pct = total > 0 ? (score / total) : 0.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                pct >= 0.7 ? Icons.emoji_events_rounded : Icons.star_half_rounded,
                size: 48,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pct >= 0.7 ? 'Excelente Trabalho!' : 'Bom Esforço!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Você acertou $score de $total perguntas da lição de hoje.',
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.stars, color: Colors.amber, size: 18),
                  label: Text('+${score * 10} XP'),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 18),
                  label: Text('${_ctrl.streak} dias seguidos'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refazer'),
                  onPressed: () => _ctrl.restart(),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Concluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
