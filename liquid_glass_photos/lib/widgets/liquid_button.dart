import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// A reusable button component with the Liquid Glass effect.
/// 
/// Wraps content in a [LiquidGlass] lens and handles interactions.
/// Designed to be used within a [LiquidGlassView] or as a standalone
/// widget if the parent supports it (though usually requires a [LiquidGlassView] ancestor).
class LiquidButton extends LiquidGlass {
  const LiquidButton({
    required super.child,
    super.width = 80,
    super.height = 40,
    super.blur = const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
    super.chromaticAberration = 0.0,
    Color? color,
    LiquidGlassShape? shape,
    required super.position,
  }) : super(
         color: color ?? const Color(0x1A000000), // Colors.black.withValues(alpha: 0.1)
         shape: shape ?? const RoundedRectangleShape(cornerRadius: 24),
       );
}
