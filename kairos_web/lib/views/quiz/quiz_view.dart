import 'package:flutter/material.dart';
import '../../controllers/quiz_controller.dart';
import '../../models/quiz_question.dart';

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
    widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quiz Bíblico', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.controller.currentCategory,
                    dropdownColor: theme.cardTheme.color,
                    items: const [
                      DropdownMenuItem(value: 'adultos', child: Text('Adultos')),
                      DropdownMenuItem(value: 'jovens', child: Text('Jovens')),
                      DropdownMenuItem(value: 'geral', child: Text('Geral')),
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    ],
                    onChanged: (cat) {
                      if (cat != null) widget.controller.selectCategory(cat);
                    },
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.controller.streak}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.stars, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.controller.totalXp} XP',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;

          if (ctrl.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ctrl.isCompleted) {
            return _buildCompletionView(context, ctrl);
          }

          final question = ctrl.currentQuestion;
          if (question == null) {
            return const Center(child: Text('Nenhuma pergunta disponível.'));
          }

          return Center(
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
                        if (question.verseRef != null)
                          Chip(
                            label: Text(
                              '📖 ${question.verseRef}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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

                    // Alternativas (renderizadas diretamente sem unbounded constraints)
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
                        ctrl.hasSubmitted ? 'Próxima Pergunta' : 'Verificar Resposta',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                'Você acertou $score de $total questões!',
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
              FilledButton.icon(
                onPressed: () => ctrl.restart(),
                icon: const Icon(Icons.replay),
                label: const Text('Jogar Novamente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
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
