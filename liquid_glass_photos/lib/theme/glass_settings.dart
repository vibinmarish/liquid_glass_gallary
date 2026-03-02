import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Centralized glass settings for the entire application.
/// Adjust these values here to apply them globally.
class AppGlassSettings {
  /// Premium high-refraction settings for buttons and interactive elements.
  /// Used for "Select" and "Grid" buttons.
  static const premiumButton = LiquidGlassSettings(
    thickness: 30,
    refractiveIndex: 1.59,
    blur: 3,
    chromaticAberration: 0.002,
  );

  /// Default settings for bottom bars and large surfaces.
  static const bottomBar = LiquidGlassSettings(
    thickness: 30,
    blur: 2.5,
    refractiveIndex: 1.59,
    lightAngle: 0.7853981633974483, // 0.25 * pi
    lightIntensity: 0.6,
    ambientStrength: 1,
    saturation: 0.7,
    chromaticAberration: 0.002,
  );

  /// Settings for pop-up menus and cards.
  static const menu = LiquidGlassSettings(
    thickness: 30,
    blur: 6,
    refractiveIndex: 1.59,
    chromaticAberration: 0.002,
    lightIntensity: 0.6,
    ambientStrength: 1.0,
  );

  /// Subtle settings for secondary overlays or toolbars.
  static final secondaryToolbar = LiquidGlassSettings(
    blur: 12,
    glassColor: Colors.white.withValues(alpha: 0.1),
    thickness: 15,
    refractiveIndex: 1.4,
  );

  /// Low-profile settings for the gallery viewer HUD.
  static const viewerHud = LiquidGlassSettings(
    thickness: 25,
    blur: 3,
    refractiveIndex: 1.59,
    chromaticAberration: 0.3,
    lightIntensity: 0.6,
    ambientStrength: 1,
    saturation: 0.7,
  );

  /// Darkened settings for the gallery viewer control pill.
  static final viewerControlPill = LiquidGlassSettings(
    blur: 15,
    glassColor: Colors.black.withValues(alpha: 0.3),
    thickness: 20,
    refractiveIndex: 1.5,
  );

  /// Standard settings for dialogs and pop-ups.
  static const dialog = LiquidGlassSettings(
    blur: 15,
    glassColor: Color(0x1AFFFFFF), // 0.1 alpha white
    chromaticAberration: 0.0,
    thickness: 20,
    refractiveIndex: 1.5,
  );
}

/// Recommended presets for different UI surfaces.
class RecommendedGlassSettings {
  /// Lightweight surface for app bars and sidebars.
  static const surface = LiquidGlassSettings(
    thickness: 10,
    blur: 1.5,
    refractiveIndex: 1.2,
    lightIntensity: 0.4,
    ambientStrength: 0.8,
  );

  /// Thick, rich glass for floating overlays and cards.
  static const overlay = LiquidGlassSettings(
    thickness: 30,
    blur: 2.5,
    refractiveIndex: 1.59,
    lightAngle: 0.7853981633974483, // 0.25 * pi
    lightIntensity: 0.6,
    ambientStrength: 1,
    saturation: 0.7,
    chromaticAberration: 0.002,
  );
}
