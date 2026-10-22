import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/database/database_manager.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/content_manager.dart';
import '../../services/theme_service.dart';
import '../navigation/main_navigation_view.dart';

/// Splash Screen Editorial com Shimmer luminoso e boot assíncrono.
/// Filosofia /ponytail: sem bibliotecas externas, usando a stdlib de animação do Flutter.
class SplashView extends StatefulWidget {
  final Duration minDuration;
  final Widget Function()? homeBuilder;

  const SplashView({
    super.key,
    this.minDuration = const Duration(milliseconds: 1200),
    this.homeBuilder,
  });

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  late final AnimationController _subtitleController;
  late final Animation<double> _subtitleAnimation;

  Timer? _minWaitTimer;

  @override
  void initState() {
    super.initState();

    // Ciclo de ~1.2s com Curves.easeInOut para o brilho luminoso no título
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );

    // Fade-in sutil para o subtítulo editorial
    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _subtitleAnimation = CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeIn,
    );

    _subtitleController.forward();

    _bootstrap();
  }

  /// Inicializa serviços essenciais em paralelo com tempo mínimo garantido
  Future<void> _bootstrap() async {
    final completer = Completer<void>();
    _minWaitTimer = Timer(widget.minDuration, () {
      if (!completer.isCompleted) completer.complete();
    });

    // Inicia recuperação de sessão em segundo plano
    unawaited(AuthService().init().catchError((e) {
      debugPrint('[SplashView] Erro ao carregar auth em background: $e');
    }));

    try {
      await Future.wait([
        DatabaseManager().initialize(),
        ThemeService().init(),
        AudioService().init(),
        ContentManager().init(),
        completer.future,
      ]);
    } catch (e, st) {
      debugPrint('[SplashView] Erro durante o boot assíncrono: $e\n$st');
      if (!completer.isCompleted) {
        await completer.future;
      }
    }

    if (!mounted) return;

    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.homeBuilder != null
                ? widget.homeBuilder!()
                : const MainNavigationView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _minWaitTimer?.cancel();
    _shimmerController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    // Brilho luminoso sutil e editorial
    final highlightColor = isDark
        ? Color.lerp(primaryColor, Colors.white, 0.85)!
        : Color.lerp(primaryColor, Colors.white, 0.70)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone de abertura
                Icon(
                  Icons.auto_stories,
                  size: 64,
                  color: primaryColor,
                ),
                const SizedBox(height: 20),

                // Título "Kairós" com Shimmer ShaderMask animado
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    final t = _shimmerAnimation.value;
                    final beginX = -2.2 + (3.2 * t);
                    final endX = -1.0 + (3.2 * t);

                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment(beginX, -0.2),
                          end: Alignment(endX, 0.2),
                          colors: [
                            primaryColor,
                            highlightColor,
                            primaryColor,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'Kairós',
                        textAlign: TextAlign.center,
                        style: (theme.textTheme.headlineLarge ??
                                const TextStyle(fontSize: 32))
                            .copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Subtítulo editorial com fade-in suave
                FadeTransition(
                  opacity: _subtitleAnimation,
                  child: Text(
                    'Adoração, Comunhão e Estudo',
                    textAlign: TextAlign.center,
                    style: (theme.textTheme.bodyMedium ??
                            const TextStyle(fontSize: 14))
                        .copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
