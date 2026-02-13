import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_button.dart';

class PermissionScreen extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  
  const PermissionScreen({
    super.key,
    required this.onRequestPermission,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? GlassColors.textPrimaryDark : GlassColors.textPrimaryLight;
    final secondaryColor = isDark ? GlassColors.textSecondaryDark : GlassColors.textSecondaryLight;
    
    return Scaffold(
      backgroundColor: isDark ? GlassColors.backgroundDark : GlassColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 80,
                  color: GlassColors.accentBlue,
                ),
                const SizedBox(height: 32),
                Text(
                  'Access Your Photos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Liquid Glass Photos needs access to your library to display and organize your beautiful memories.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: secondaryColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                GlassButton(
                  onPressed: onRequestPermission,
                  child: const Text('Allow Access', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onOpenSettings,
                  child: Text(
                    'Open Settings',
                    style: TextStyle(
                      color: GlassColors.accentBlue,
                      fontWeight: FontWeight.w600,
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
