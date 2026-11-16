import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

/// Wizard rápido de configuração inicial exibido ao final do tour guiado.
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

  String _lessonCategory = 'adultos';
  String _devotionalCategory = 'matinal';
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _classCodeController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _cityController.dispose();
    _classCodeController.dispose();
    super.dispose();
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
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Configuração Rápida (${_step + 1}/$_totalSteps)'),
        automaticallyImplyLeading: false,
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
                  _buildLocationStep(theme),
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
                      onPressed: () {
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
                    onPressed: _next,
                    icon: Icon(_step + 1 == _totalSteps ? Icons.check_rounded : Icons.arrow_forward_rounded),
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
    final styles = [
      (AppThemeStyle.materialYou, 'Material You', Icons.palette_outlined),
      (AppThemeStyle.realGlass, 'Real Glass', Icons.lens_blur_rounded),
      (AppThemeStyle.appleGlass, 'Apple Glass', Icons.auto_awesome_outlined),
      (AppThemeStyle.classicBook, 'Livro Sépia', Icons.menu_book_rounded),
    ];

    final colors = [
      const Color(0xFF1B5E20),
      const Color(0xFF0D47A1),
      const Color(0xFF6A1B9A),
      const Color(0xFF8D6E63),
      const Color(0xFF00695C),
    ];

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Estilo & Cor Principal', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Escolha a aparência que mais combina com você.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
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
            const SizedBox(height: 24),
            Text('Cor de Destaque', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: colors.map((c) {
                final selected = themeService.currentColor.toARGB32() == c.toARGB32();
                return InkWell(
                  onTap: () => themeService.setCustomColor(c),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 42,
                    height: 42,
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
        Text('Lição & Devocional', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Personalize sua categoria padrão de estudo.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Text('Escola Sabatina', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'adultos', label: Text('Adultos')),
            ButtonSegment(value: 'jovens', label: Text('Jovens')),
          ],
          selected: {_lessonCategory},
          onSelectionChanged: (s) {
            setState(() => _lessonCategory = s.first);
          },
        ),
        const SizedBox(height: 24),
        Text('Meditação Diária', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'matinal', label: Text('Matinal')),
            ButtonSegment(value: 'jovens', label: Text('Jovens')),
            ButtonSegment(value: 'mulher', label: Text('Mulher')),
          ],
          selected: {_devotionalCategory},
          onSelectionChanged: (s) => setState(() => _devotionalCategory = s.first),
        ),
      ],
    );
  }

  Widget _buildLocationStep(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Localização & Pôr do Sol', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Informe sua cidade para calcular o horário do pôr do sol.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'Cidade (opcional)',
            hintText: 'Ex: São Paulo, SP',
            prefixIcon: Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthAndClassStep(ThemeData theme) {
    final auth = AuthService();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Conta & Turma', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Conecte sua conta para sincronizar progresso ou entre em uma turma.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
          decoration: const InputDecoration(
            labelText: 'Código da Turma (opcional)',
            hintText: 'Ex: KAIR-2026',
            prefixIcon: Icon(Icons.groups_outlined),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
