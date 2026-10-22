import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

class ProfileDialog extends StatelessWidget {
  const ProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ProfileDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = AuthService();
    final themeService = ThemeService();

    return AnimatedBuilder(
      animation: Listenable.merge([auth, themeService]),
      builder: (context, _) {
        final user = auth.currentUser;
        final isAuth = auth.isAuthenticated;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Row(
            children: [
              Icon(Icons.person_outline_rounded),
              SizedBox(width: 8),
              Text('Perfil & Preferências'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção 1 — Card de Conta & Sincronização Nuvem (Supabase OAuth)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (isAuth && user != null && user.avatarUrl.isNotEmpty)
                              CircleAvatar(
                                radius: 26,
                                backgroundImage: NetworkImage(user.avatarUrl),
                                onBackgroundImageError: (_, __) {},
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              )
                            else if (isAuth && user != null)
                              CircleAvatar(
                                radius: 26,
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              )
                            else
                              const CircleAvatar(
                                radius: 26,
                                child: Icon(Icons.person_outline, size: 28),
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAuth && user != null ? user.name : 'Visitante (Modo Local)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAuth && user != null
                                        ? user.email
                                        : 'Conecte sua conta Google para sincronizar favoritos, destaques e preferências na nuvem.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        isAuth ? Icons.cloud_done_rounded : Icons.cloud_off_outlined,
                                        size: 15,
                                        color: isAuth ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          isAuth
                                              ? 'Sincronizado com Supabase'
                                              : 'Salvo apenas neste dispositivo',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isAuth ? FontWeight.w600 : FontWeight.w500,
                                            color: isAuth ? Colors.green : Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: isAuth
                              ? OutlinedButton.icon(
                                  onPressed: () => auth.signOut(),
                                  icon: const Icon(Icons.logout_rounded, size: 18),
                                  label: const Text('Sair da Conta'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed: () => auth.signInWithGoogle(),
                                  icon: const Icon(Icons.login_rounded, size: 18),
                                  label: const Text('Entrar com Google'),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Seção 2 — Conteúdo Padrão (Sincronizado)
                  const Text(
                    'Conteúdo Padrão',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escolha qual versão abrir por padrão ao iniciar o aplicativo:',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Escola Sabatina Padrão
                  Row(
                    children: [
                      Icon(Icons.school_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Lição da Escola Sabatina',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'adultos',
                          icon: Icon(Icons.menu_book_outlined, size: 16),
                          label: Text('Adultos'),
                        ),
                        ButtonSegment(
                          value: 'jovens',
                          icon: Icon(Icons.bolt_outlined, size: 16),
                          label: Text('Jovens'),
                        ),
                      ],
                      selected: {themeService.defaultSabbathSchoolCategory},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) {
                          AuthService().syncPreferencesToCloud(sabbathSchoolCategory: sel.first);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Meditação Diária Padrão
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Meditação Matinal',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'diario',
                          icon: Icon(Icons.wb_sunny_outlined, size: 16),
                          label: Text('Diária'),
                        ),
                        ButtonSegment(
                          value: 'jovem',
                          icon: Icon(Icons.bolt_outlined, size: 16),
                          label: Text('Jovens'),
                        ),
                        ButtonSegment(
                          value: 'mulher',
                          icon: Icon(Icons.spa_outlined, size: 16),
                          label: Text('Mulher'),
                        ),
                      ],
                      selected: {themeService.defaultDevotionalCategory},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) {
                          AuthService().syncPreferencesToCloud(devotionalCategory: sel.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
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
