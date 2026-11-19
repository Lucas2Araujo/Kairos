import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../controllers/devotional_controller.dart';
import '../../core/utils/bible_extractor.dart';
import '../../core/utils/system_share_download.dart';
import '../../models/devotional.dart';
import '../../services/egw_service.dart';
import '../../services/solar_service.dart';
import '../../services/theme_service.dart';
import '../bible/widgets/bible_verse_preview_modal.dart';
import '../egw/egw_books_view.dart';
import '../egw/egw_reader_view.dart';

class PorDoSolView extends StatefulWidget {
  final DevotionalController devotionalController;

  const PorDoSolView({
    super.key,
    required this.devotionalController,
  });

  @override
  State<PorDoSolView> createState() => _PorDoSolViewState();
}

class _PorDoSolViewState extends State<PorDoSolView> {
  SolarCity _selectedCity = SolarService.defaultCity;
  Timer? _countdownTimer;
  Duration _timeUntilSabbath = Duration.zero;
  bool _isSabbathHours = false;
  DateTime? _sunsetTime;
  Devotional? _meditation;
  bool _isLoadingMeditation = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCity();
    _recalculateSunset();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
    _loadMeditation();
  }

  Future<void> _loadSavedCity() async {
    final city = await SolarService.getSavedCity();
    if (!mounted) return;
    setState(() {
      _selectedCity = city;
      _recalculateSunset();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _recalculateSunset() {
    final now = DateTime.now();
    _sunsetTime = SolarService.calculateSunset(
      date: now,
      latitude: _selectedCity.latitude,
      longitude: _selectedCity.longitude,
      timezoneOffset: _selectedCity.timezoneOffset,
    );
    _updateCountdown();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    // Horário de Pôr do sol na próxima ou atual sexta-feira
    final fridaySunset = SolarService.getFridaySunset(
      referenceDate: now,
      city: _selectedCity,
    );

    // O Sábado vai do pôr do sol de sexta até o pôr do sol de sábado
    final saturdaySunset = SolarService.calculateSunset(
      date: SolarService.getNextFriday(now).weekday == DateTime.friday && now.weekday == DateTime.saturday
          ? now
          : now.add(Duration(days: (DateTime.saturday - now.weekday) % 7)),
      latitude: _selectedCity.latitude,
      longitude: _selectedCity.longitude,
      timezoneOffset: _selectedCity.timezoneOffset,
    ) ?? fridaySunset.add(const Duration(hours: 24));

    if (now.weekday == DateTime.friday && now.isAfter(fridaySunset)) {
      _isSabbathHours = true;
    } else if (now.weekday == DateTime.saturday && now.isBefore(saturdaySunset)) {
      _isSabbathHours = true;
    } else {
      _isSabbathHours = false;
    }

    if (_isSabbathHours) {
      _timeUntilSabbath = Duration.zero;
    } else {
      final diff = fridaySunset.difference(now);
      _timeUntilSabbath = diff.isNegative ? Duration.zero : diff;
    }
    setState(() {});
  }

  Future<void> _loadMeditation() async {
    setState(() => _isLoadingMeditation = true);
    try {
      final now = DateTime.now();
      // Carrega para a sexta-feira corrente mais recente
      DateTime targetDate = now;
      if (now.weekday != DateTime.friday) {
        // Encontra a sexta-feira mais próxima anterior ou de hoje
        final diff = (now.weekday - DateTime.friday) % 7;
        targetDate = now.subtract(Duration(days: diff));
      }

      final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
      _meditation = await widget.devotionalController.fetchDevotionalDirect(
        date: dateStr,
        category: 'pordosol',
      );
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingMeditation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ts = ThemeService();
    final isGlass = ts.hasAtmosphericBackground;
    final hasGlobalBg = ts.hasGlobalBackgroundShell;
    final now = DateTime.now();
    final isFriday = now.weekday == DateTime.friday;

    return Scaffold(
      backgroundColor: hasGlobalBg ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: ts.isAscii
            ? theme.colorScheme.surface
            : (ts.isWin95
                ? const Color(0xFF000080)
                : (isGlass ? Colors.transparent : null)),
        foregroundColor: ts.isWin95 ? Colors.white : null,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: ts.isAscii
            ? Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 1.5))
            : (ts.isHoloRetro
                ? const Border(bottom: BorderSide(color: Color(0xFF33B5E5), width: 2))
                : null),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_twilight_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Meditação do Pôr do Sol',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Meditação Semanal do Pôr do Sol
                _buildMeditationSection(theme, isGlass),
                const SizedBox(height: 24),

                // Card Solar & Feliz Sábado ao fim da leitura
                _buildSolarCountdownCard(theme, isGlass, isFriday),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolarCountdownCard(ThemeData theme, bool isGlass, bool isFriday) {
    final todaySunsetStr = _sunsetTime != null ? SolarService.formatTime(_sunsetTime!) : '--:--';
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF4A2511).withValues(alpha: 0.85),
                  const Color(0xFF2B193D).withValues(alpha: 0.85),
                ]
              : [
                  const Color(0xFFFFE0B2),
                  const Color(0xFFFFCCBC),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 18, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Text(
                    _selectedCity.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wb_twilight_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Pôr do Sol: $todaySunsetStr',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orange.shade200 : Colors.deepOrange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Contagem Regressiva ou Status de Horas Sagradas
          if (_isSabbathHours)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feliz Sábado!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Estamos nas horas sagradas do Santo Sábado do Senhor.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              isFriday ? 'Contagem Regressiva para o Sábado' : 'Próximo Pôr do Sol de Sexta-feira',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCountdownBox(theme, _timeUntilSabbath.inDays.toString().padLeft(2, '0'), 'DIAS'),
                const SizedBox(width: 8),
                _buildCountdownBox(theme, (_timeUntilSabbath.inHours % 24).toString().padLeft(2, '0'), 'HORAS'),
                const SizedBox(width: 8),
                _buildCountdownBox(theme, (_timeUntilSabbath.inMinutes % 60).toString().padLeft(2, '0'), 'MIN'),
                const SizedBox(width: 8),
                _buildCountdownBox(theme, (_timeUntilSabbath.inSeconds % 60).toString().padLeft(2, '0'), 'SEG'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownBox(ThemeData theme, String value, String unit) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              letterSpacing: 0.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _openEgwReference(String citation) {
    final lower = citation.toLowerCase();
    for (final book in EgwService.defaultCatalog) {
      final title = (book['title'] ?? '').toLowerCase();
      final abbr = (book['abbr'] ?? '').toLowerCase();
      if (title.isNotEmpty && (lower.contains(title) || (abbr.length >= 2 && lower.contains(abbr)))) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EgwReaderView(
              bookId: book['id']!,
              bookTitle: book['title']!,
            ),
          ),
        );
        return;
      }
    }
    EgwBooksView.navigateTo(context);
  }

  Widget _buildRichMeditationContent(String content, ThemeData theme) {
    final egwRegex = RegExp(r'\(([A-ZÀ-Ú][^()]{4,80}?,\s*(?:\d{4},\s*)?p\.\s*\d+(?:-\d+)?)\)');
    final bibleMatches = BibleExtractor.findBibleReferences(content);
    final tokens = <({int start, int end, String text, bool isEgw})>[
      for (final m in egwRegex.allMatches(content))
        (start: m.start, end: m.end, text: m.group(0)!, isEgw: true),
      for (final b in bibleMatches)
        (start: b.start, end: b.end, text: b.rawText, isEgw: false),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final tok in tokens) {
      if (tok.start < lastEnd) continue;
      if (tok.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, tok.start)));
      }

      spans.add(
        TextSpan(
          text: content.substring(tok.start, tok.end),
          style: TextStyle(
            color: tok.isEgw ? Colors.orangeAccent : theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: (tok.isEgw ? Colors.orangeAccent : theme.colorScheme.primary)
                .withValues(alpha: 0.5),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (tok.isEgw) {
                _openEgwReference(tok.text);
              } else {
                final cleanRef = BibleExtractor.cleanReference(tok.text);
                BibleVersePreviewModal.show(
                  context,
                  reference: cleanRef,
                  references: BibleExtractor.getContiguousReferences(content, cleanRef),
                  contextTitle: 'Meditação do Pôr do Sol',
                );
              }
            },
        ),
      );
      lastEnd = tok.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          fontSize: 15,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildMeditationSection(ThemeData theme, bool isGlass) {
    if (_isLoadingMeditation) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final m = _meditation;
    if (m == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'Nenhuma meditação de Pôr do Sol disponível para esta semana.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isGlass
            ? theme.colorScheme.surface.withValues(alpha: 0.7)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                m.publishedAt,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (m.verseText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“${m.verseText}”',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  Builder(
                    builder: (ctx) {
                      final ref = m.verseReference.trim().isNotEmpty
                          ? m.verseReference.trim()
                          : (BibleExtractor.findBibleReferences(m.content).firstOrNull?.rawText ?? '');
                      if (ref.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () => BibleVersePreviewModal.show(
                            context,
                            reference: BibleExtractor.cleanReference(ref),
                            contextTitle: 'Versículo em Destaque',
                          ),
                          child: Text(
                            '— $ref',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildRichMeditationContent(m.content, theme),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Compartilhar Meditação'),
              onPressed: () async {
                final text = '🌅 *${m.title}*\n\n'
                    '${m.verseText.isNotEmpty ? '“${m.verseText.trim()}” — ${m.verseReference}\n\n' : ''}'
                    '${m.content.trim()}\n\n(Compartilhado via Kairós)';
                final shared = await SystemShareDownload.shareText(
                  text: text,
                  subject: m.title,
                );
                if (!shared && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Meditação copiada para compartilhamento!'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
