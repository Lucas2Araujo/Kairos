import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Configurações'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aparência',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                // Modo Claro / Escuro / Sistema
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Modo de Tema'),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeService.themeMode,
                    dropdownColor: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Sistema (Auto)'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Escuro'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Claro'),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) themeService.setThemeMode(mode);
                    },
                  ),
                ),

                // AMOLED True Black (disponível quando escuro ou sistema em modo escuro)
                if (themeService.themeMode == ThemeMode.dark ||
                    (themeService.themeMode == ThemeMode.system &&
                        MediaQuery.of(context).platformBrightness == Brightness.dark))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Modo AMOLED (Preto Puro)'),
                    subtitle: const Text('Otimizado para economia de energia em telas OLED/AMOLED'),
                    value: themeService.isAmoled,
                    onChanged: (val) => themeService.setAmoled(val),
                  ),

                // Tipografia & Acessibilidade
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.font_download_outlined),
                  title: const Text('Fonte de Leitura'),
                  trailing: DropdownButton<String>(
                    value: themeService.fontFamily,
                    dropdownColor: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    items: const [
                      DropdownMenuItem(
                        value: 'AppSans',
                        child: Text('AppSans (Padrão)'),
                      ),
                      DropdownMenuItem(
                        value: 'HymnSerif',
                        child: Text('HymnSerif (Clássica)'),
                      ),
                      DropdownMenuItem(
                        value: 'Montserrat',
                        child: Text('Montserrat'),
                      ),
                      DropdownMenuItem(
                        value: 'OpenDyslexic',
                        child: Text('OpenDyslexic (Dislexia)'),
                      ),
                    ],
                    onChanged: (font) {
                      if (font != null) themeService.setFontFamily(font);
                    },
                  ),
                ),

                // Zoom / Escala do Texto
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.format_size),
                  title: const Text('Tamanho da Fonte'),
                  subtitle: Slider(
                    value: themeService.fontSizeMultiplier,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    label: '${(themeService.fontSizeMultiplier * 100).round()}%',
                    onChanged: (val) => themeService.setFontSizeMultiplier(val),
                  ),
                  trailing: Text(
                    '${(themeService.fontSizeMultiplier * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Cores de Destaque (Material 3)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),

                // Paleta de cores M3
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: ThemeService.colorSeeds.entries.map((entry) {
                    final isSelected = themeService.colorKey == entry.key;
                    return InkWell(
                      onTap: () => themeService.setColorSeed(entry.key),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: entry.value.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 20, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Conta & Sincronização',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined, size: 32),
                  title: const Text('Entrar com Google'),
                  subtitle: const Text('Sincronize favoritos e notas via Supabase'),
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login com Google (Supabase OAuth) iniciado no navegador.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Entrar'),
                  ),
                ),

                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Sobre o Kairós',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text('Versão 1.0.0 (Web)'),
                const Text('Bíblia Sagrada, Hinário Adventista e Lições da Escola Sabatina.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}
