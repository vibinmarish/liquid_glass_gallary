import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../theme/glass_theme.dart';

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
    final primaryColor =
        isDark ? GlassColors.textPrimaryDark : GlassColors.textPrimaryLight;
    final secondaryColor =
        isDark ? GlassColors.textSecondaryDark : GlassColors.textSecondaryLight;

    return Scaffold(
      backgroundColor:
          isDark ? GlassColors.backgroundDark : GlassColors.backgroundLight,
      body: LiquidGlassScope.stack(
        background: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.photo_on_rectangle,
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
                  const SizedBox(height: 120), // Space for glass button overlay
                ],
              ),
            ),
          ),
        ),
        content: AdaptiveLiquidGlassLayer(
          quality: GlassQuality.premium,
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassButton.custom(
                    onTap: onRequestPermission,
                    width: 200,
                    height: 50,
                    shape: const LiquidRoundedRectangle(borderRadius: 25),
                    child: const Center(
                      child: Text(
                        'Allow Access',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
      ),
    );
  }
}
