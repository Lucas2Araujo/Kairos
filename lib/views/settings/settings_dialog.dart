import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../downloads/downloads_dialog.dart';
import 'update_dialog.dart';

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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Configurações'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aparência',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Modo Claro / Escuro / AMOLED / Sépia / Sistema
                  Row(
                    children: [
                      const Icon(Icons.brightness_6, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Modo de Tema',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      DropdownButton<String>(
                        value: themeService.activeThemePreset,
                        dropdownColor: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(8),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('Sistema (Auto)'),
                          ),
                          DropdownMenuItem(
                            value: 'light',
                            child: Text('Claro'),
                          ),
                          DropdownMenuItem(
                            value: 'dark',
                            child: Text('Escuro'),
                          ),
                          DropdownMenuItem(
                            value: 'amoled',
                            child: Text('AMOLED (Preto Puro)'),
                          ),
                          DropdownMenuItem(
                            value: 'sepia',
                            child: Text('Leitura / Sépia'),
                          ),
                        ],
                        onChanged: (preset) {
                          if (preset != null) themeService.setThemePreset(preset);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tipografia & Acessibilidade
                  Row(
                    children: [
                      const Icon(Icons.font_download_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Fonte de Leitura',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      DropdownButton<String>(
                        value: themeService.fontFamily,
                        dropdownColor: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(8),
                        isDense: true,
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
                            child: Text('OpenDyslexic'),
                          ),
                        ],
                        onChanged: (font) {
                          if (font != null) themeService.setFontFamily(font);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Zoom / Escala do Texto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.format_size, size: 20),
                              SizedBox(width: 8),
                              Text('Tamanho da Fonte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text(
                            '${(themeService.fontSizeMultiplier * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Slider(
                        value: themeService.fontSizeMultiplier,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: '${(themeService.fontSizeMultiplier * 100).round()}%',
                        onChanged: (val) => themeService.setFontSizeMultiplier(val),
                      ),
                    ],
                  ),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Leitura da Bíblia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Alinhamento do Texto Bíblico
                  Row(
                    children: [
                      const Icon(Icons.format_align_left, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Alinhamento',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      SegmentedButton<TextAlign>(
                        segments: const [
                          ButtonSegment<TextAlign>(
                            value: TextAlign.left,
                            icon: Icon(Icons.format_align_left, size: 16),
                            label: Text('Esq.'),
                          ),
                          ButtonSegment<TextAlign>(
                            value: TextAlign.justify,
                            icon: Icon(Icons.format_align_justify, size: 16),
                            label: Text('Just.'),
                          ),
                        ],
                        selected: {themeService.bibleTextAlign},
                        onSelectionChanged: (selection) {
                          if (selection.isNotEmpty) {
                            themeService.setBibleTextAlign(selection.first);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Modo de Texto Corrido vs Versículo a Versículo
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.view_headline, size: 20),
                    title: const Text('Modo Texto Corrido', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Exibe a leitura em parágrafos contínuos', style: TextStyle(fontSize: 12)),
                    value: themeService.isContinuousReading,
                    onChanged: (val) => themeService.setContinuousReading(val),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => DownloadsDialog.show(context),
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Gerenciar Traduções e Downloads'),
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
                  Builder(
                    builder: (context) {
                      final auth = AuthService();
                      return AnimatedBuilder(
                        animation: auth,
                        builder: (context, _) {
                          final user = auth.currentUser;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      user != null ? Icons.check_circle : Icons.account_circle_outlined,
                                      size: 24,
                                      color: user != null ? Colors.green : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        user != null ? user.name : 'Entrar com Google',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user != null ? user.email : 'Sincronize favoritos e notas via Supabase',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: user != null
                                      ? OutlinedButton.icon(
                                          onPressed: () => auth.signOut(),
                                          icon: const Icon(Icons.logout, size: 18),
                                          label: const Text('Sair da Conta'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                          ),
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: () => auth.signInWithGoogle(),
                                          icon: const Icon(Icons.login, size: 18),
                                          label: const Text('Entrar'),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Sobre o Kairós',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text('Versão 1.0.0'),
                  const Text('Bíblia Sagrada, Hinário Adventista e Lições da Escola Sabatina.'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => UpdateDialog.show(context),
                      icon: const Icon(Icons.system_update_outlined, size: 18),
                      label: const Text('Verificar Atualizações (OTA)'),
                    ),
                  ),
                ],
              ),
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
