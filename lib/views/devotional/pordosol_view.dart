import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/devotional_controller.dart';
import '../../models/devotional.dart';
import '../../services/solar_service.dart';
import '../../services/theme_service.dart';

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
    _recalculateSunset();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
    _loadMeditation();
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
      await widget.devotionalController.loadDevotional(
        date: dateStr,
        category: 'pordosol',
      );
      _meditation = widget.devotionalController.currentDevotional;
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingMeditation = false);
    }
  }

  Future<void> _openFindChurch() async {
    final uri = Uri.parse('https://igrejas.adventistas.org/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlass = ThemeService().isAnyGlass;
    final now = DateTime.now();
    final isFriday = now.weekday == DateTime.friday;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_twilight_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Meditação do Pôr do Sol', style: TextStyle(fontWeight: FontWeight.bold)),
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
                // Card Solar & Contagem Regressiva
                _buildSolarCountdownCard(theme, isGlass, isFriday),
                const SizedBox(height: 16),

                // Botão de Destaque "Encontre uma Igreja Adventista"
                _buildFindChurchButton(theme),
                const SizedBox(height: 24),

                // Meditação Semanal do Pôr do Sol
                _buildMeditationSection(theme, isGlass),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolarCountdownCard(ThemeData theme, bool isGlass, bool isFriday) {
    final todaySunsetStr = _sunsetTime != null ? SolarService.formatTime(_sunsetTime!) : '--:--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isGlass
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  const Icon(Icons.location_on_rounded, size: 20, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  DropdownButton<SolarCity>(
                    value: _selectedCity,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Icons.arrow_drop_down),
                    borderRadius: BorderRadius.circular(16),
                    items: SolarService.predefinedCities.map((city) {
                      return DropdownMenuItem<SolarCity>(
                        value: city,
                        child: Text(
                          city.displayName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (newCity) {
                      if (newCity != null) {
                        setState(() {
                          _selectedCity = newCity;
                          _recalculateSunset();
                        });
                      }
                    },
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'Pôr do Sol: $todaySunsetStr',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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

  Widget _buildFindChurchButton(ThemeData theme) {
    return FilledButton.icon(
      key: const Key('find_adventist_church_button'),
      onPressed: _openFindChurch,
      icon: const Icon(Icons.church_rounded, size: 22),
      label: const Text(
        'Encontre uma Igreja Adventista',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Meditação da Semana',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                m.publishedAt,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            m.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (m.verseText.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                  if (m.verseReference.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '— ${m.verseReference}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SelectableText(
            m.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
