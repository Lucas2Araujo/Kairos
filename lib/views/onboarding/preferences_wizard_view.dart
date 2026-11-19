import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/gamification_service.dart';
import '../../services/solar_service.dart';
import '../../services/theme_service.dart';

/// Wizard completo de configuração inicial exibido após o tour guiado.
/// Apresenta todos os 8 estilos de tema, barra flutuante, metas diárias, busca real
/// de cidades para cálculo do pôr do sol e ingresso em turmas.
class PreferencesWizardView extends StatefulWidget {
  const PreferencesWizardView({super.key});

  static Future<void> show(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PreferencesWizardView(),
      ),
    );
  }

  @override
  State<PreferencesWizardView> createState() => _PreferencesWizardViewState();
}

class _PreferencesWizardViewState extends State<PreferencesWizardView> {
  final PageController _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  late String _lessonCategory;
  late String _devotionalCategory;
  late int _dailyGoalMinutes;
  SolarCity _selectedCity = SolarService.defaultCity;
  List<SolarCity> _filteredCities = SolarService.predefinedCities;
  bool _isFinishing = false;

  final TextEditingController _citySearchController = TextEditingController();
  final TextEditingController _classCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final ts = ThemeService();
    _lessonCategory = ts.defaultSabbathSchoolCategory;
    _devotionalCategory = ts.defaultDevotionalCategory;
    _dailyGoalMinutes = GamificationService().dailyGoalMinutes;
    _loadSavedCity();
  }

  Future<void> _loadSavedCity() async {
    final saved = await SolarService.getSavedCity();
    if (!mounted) return;
    setState(() => _selectedCity = saved);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _citySearchController.dispose();
    _classCodeController.dispose();
    super.dispose();
  }

  void _filterCities(String query) {
    setState(() {
      _filteredCities = SolarService.searchCities(query);
    });
  }

  Future<void> _finishWizard() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    try {
      await SolarService.saveCity(_selectedCity);
      final classCode = _classCodeController.text.trim().toUpperCase();
      if (classCode.isNotEmpty) {
        try {
          final ok = await ClassroomService().joinClassroom(classCode);
          if (mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Código de turma não encontrado. Você pode tentar novamente na aba Turmas.'),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Turma: $e')),
            );
          }
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isFinishing = false);
      }
    }
  }

  void _next() {
    if (_step + 1 < _totalSteps) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishWizard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return Scaffold(
      appBar: KairosAdaptiveAppBar(
        title: 'Configuração Rápida (${_step + 1}/$_totalSteps)',
        leading: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Pular'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / _totalSteps),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildThemeStep(theme, themeService),
                  _buildStudyStep(theme, themeService),
                  _buildLocationStep(theme, themeService),
                  _buildAuthAndClassStep(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _isFinishing
                          ? null
                          : () {
                              setState(() => _step--);
                              _pageController.animateToPage(
                                _step,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                              );
                            },
                      child: const Text('Voltar'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isFinishing ? null : _next,
                    icon: _isFinishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _step + 1 == _totalSteps
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                    label: Text(_step + 1 == _totalSteps ? 'Concluir' : 'Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeStep(ThemeData theme, ThemeService themeService) {
    const styles = [
      (AppThemeStyle.materialYou, 'Material You', Icons.palette_outlined),
      (AppThemeStyle.appleGlass, 'Apple Glass', Icons.blur_on_rounded),
      (AppThemeStyle.realGlass, 'Real Glass (Apple)', Icons.lens_blur_rounded),
      (AppThemeStyle.classicBook, 'Livro Sépia', Icons.menu_book_rounded),
      (AppThemeStyle.zen, 'Zen', Icons.spa_outlined),
      (AppThemeStyle.holoRetro, 'Android 4.0 Holo', Icons.android_rounded),
      (AppThemeStyle.win95, 'Windows 95', Icons.window_rounded),
      (AppThemeStyle.ascii, 'ASCII Vintage', Icons.terminal_rounded),
    ];

    const colors = [
      Color(0xFF1B5E20),
      Color(0xFF0D47A1),
      Color(0xFF6A1B9A),
      Color(0xFF8D6E63),
      Color(0xFF00695C),
    ];

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Estilo & Visual do App',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Explore todos os 8 temas do Kairós em tempo real.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: styles.map((item) {
                final selected = themeService.themeStyle == item.$1;
                return ChoiceChip(
                  avatar: Icon(item.$3, size: 18),
                  label: Text(item.$2),
                  selected: selected,
                  onSelected: (_) => themeService.setThemeStyle(item.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Barra de Navegação Flutuante'),
              subtitle: const Text('Atalhos rápidos flutuando no rodapé'),
              value: themeService.floatingNavBar,
              onChanged: themeService.setFloatingNavBar,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo Simplificado (Foco em Idosos)'),
              subtitle: const Text('Exibe apenas Bíblia, Hinário, Lição e Devocional com botões grandes e fonte ampliada'),
              value: themeService.simplifiedHomeMode,
              onChanged: themeService.setSimplifiedHomeMode,
            ),
            const SizedBox(height: 16),
            Text(
              'Cor de Destaque',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (themeService.locksAccentColor)
              Text(
                'Este estilo usa paleta própria fixa (você pode ajustar variantes nas Configurações).',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: colors.map((c) {
                  final selected = themeService.currentColor.toARGB32() == c.toARGB32();
                  return InkWell(
                    onTap: () => themeService.setCustomColor(c),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? theme.colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStudyStep(ThemeData theme, ThemeService themeService) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Estudo & Metas Diárias',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Suas escolhas ficam salvas imediatamente.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        Text(
          'Lição da Escola Sabatina',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'adultos', label: Text('Adultos')),
            ButtonSegment(value: 'jovens', label: Text('Jovens')),
          ],
          selected: {_lessonCategory},
          onSelectionChanged: (s) {
            final value = s.first;
            setState(() => _lessonCategory = value);
            themeService.setDefaultSabbathSchoolCategory(value);
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Meditação Diária',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'diario', label: Text('Adultos')),
            ButtonSegment(value: 'jovem', label: Text('Jovens')),
            ButtonSegment(value: 'mulher', label: Text('Mulher')),
          ],
          selected: {_devotionalCategory},
          onSelectionChanged: (s) {
            final value = s.first;
            setState(() => _devotionalCategory = value);
            themeService.setDefaultDevotionalCategory(value);
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Meta Diária com Deus (Minutos)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [10, 15, 20, 30].map((mins) {
            return ChoiceChip(
              label: Text('$mins min/dia'),
              selected: _dailyGoalMinutes == mins,
              onSelected: (_) {
                setState(() => _dailyGoalMinutes = mins);
                GamificationService().setDailyGoalMinutes(mins);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationStep(ThemeData theme, ThemeService themeService) {
    final fridaySunset = SolarService.getFormattedFridaySunset(_selectedCity);

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cidade & Pôr do Sol',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Pesquise sua cidade para calcular o início do sábado no cálculo solar NOAA.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wb_twilight_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCity.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pôr do sol sexta-feira: $fridaySunset',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lembrar pôr do sol de sexta-feira'),
                value: themeService.sunsetReminderEnabled,
                onChanged: themeService.setSunsetReminderEnabled,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _citySearchController,
                onChanged: _filterCities,
                decoration: InputDecoration(
                  labelText: 'Pesquisar cidade ou estado (ex: Campinas, SP)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _citySearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _citySearchController.clear();
                            _filterCities('');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filteredCities.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma cidade encontrada na lista (${SolarService.predefinedCities.length} cidades).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredCities.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final city = _filteredCities[idx];
                          final isSelected =
                              city.name == _selectedCity.name && city.state == _selectedCity.state;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.location_on_outlined,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                            title: Text(city.displayName),
                            subtitle: Text(
                              'Sexta: ${SolarService.getFormattedFridaySunset(city)}',
                            ),
                            onTap: () {
                              setState(() => _selectedCity = city);
                              SolarService.saveCity(city);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthAndClassStep(ThemeData theme) {
    final auth = AuthService();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Conta & Turma',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Conecte sua conta para sincronizar progresso na nuvem ou informe o código da sua classe.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (!auth.isAuthenticated)
          OutlinedButton.icon(
            onPressed: () => auth.signInWithGoogle(),
            icon: const Icon(Icons.login_rounded),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Entrar com Google'),
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.verified_user_rounded),
            title: Text(auth.currentUser?.name ?? 'Conectado'),
            subtitle: Text(auth.currentUser?.email ?? ''),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _classCodeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Código da Turma (6 caracteres - opcional)',
            hintText: 'Ex: KAIR26',
            prefixIcon: Icon(Icons.groups_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
