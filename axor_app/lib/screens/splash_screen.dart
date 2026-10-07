import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/text_styles.dart';
import '../providers/auth_provider.dart';
import 'auth/google_sign_in_screen.dart';
import 'home/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  bool _showContent = false;
  bool _showTagline = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Sequence the reveal
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showContent = true);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showTagline = true);
    });

    // Try silent sign-in and navigate
    Future.delayed(const Duration(milliseconds: 2800), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final isSignedIn = await authProvider.trySilentSignIn();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isSignedIn ? const MainScreen() : const GoogleSignInScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Animated gradient orbs in background
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              final t = _rotateController.value * 2 * math.pi;
              return Stack(
                children: [
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.2 +
                        math.sin(t) * 30,
                    right: -60 + math.cos(t * 0.7) * 20,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withAlpha(30),
                            AppColors.primary.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.15 +
                        math.cos(t * 0.5) * 25,
                    left: -80 + math.sin(t * 0.8) * 15,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.secondary.withAlpha(25),
                            AppColors.secondary.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with glow
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final glowIntensity =
                        0.2 + _pulseController.value * 0.3;
                    return Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary
                                .withAlpha((glowIntensity * 100).toInt()),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: AppColors.secondary
                                .withAlpha((glowIntensity * 50).toInt()),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/logo.png',
                    width: 140,
                    height: 140,
                  ),
                )
                    .animate(target: _showContent ? 1 : 0)
                    .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 800.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 28),

                // Brand name
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: Text(
                    'AXOR',
                    style: AppTextStyles.displayLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: 12,
                      fontSize: 44,
                    ),
                  ),
                )
                    .animate(target: _showContent ? 1 : 0)
                    .fadeIn(
                        duration: 600.ms,
                        delay: 200.ms,
                        curve: Curves.easeOut)
                    .slideY(
                        begin: 0.3,
                        end: 0,
                        duration: 600.ms,
                        delay: 200.ms),

                const SizedBox(height: 12),

                // Tagline
                Text(
                  'Your Sound. Evolved.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 3,
                    fontSize: 13,
                  ),
                )
                    .animate(target: _showTagline ? 1 : 0)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.5, end: 0, duration: 600.ms),
              ],
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withAlpha(100),
                ),
              ),
            ),
          )
              .animate(target: _showTagline ? 1 : 0)
              .fadeIn(duration: 400.ms, delay: 400.ms),
        ],
      ),
    );
  }
}
