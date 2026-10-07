import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/animated_gradient_bg.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_button.dart';
import '../home/main_screen.dart';

class GoogleSignInScreen extends StatelessWidget {
  const GoogleSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(50),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png'),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'Welcome to AXOR',
                  style: AppTextStyles.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Subtitle
                Text(
                  'Connect your Google Drive to stream your personal music library anywhere, anytime.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Glass Card containing Auth Info
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Your Music, Your Rules',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We only request read access to play audio files from your Drive.',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Error Message
                if (authProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      authProvider.errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Launch Local Library Button (Primary)
                NeonButton(
                  text: 'Open Local Library (267 Songs)',
                  icon: Icons.library_music_rounded,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),
                // Connect with Google Button (Secondary)
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_queue_rounded, color: AppColors.primary),
                  label: Text(
                    authProvider.isLoading ? 'Connecting...' : 'Connect Google Drive',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withAlpha(80)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.surfaceElevated.withAlpha(120),
                  ),
                  onPressed: authProvider.isLoading ? null : () async {
                    final success = await authProvider.signIn();
                    if (success && context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
