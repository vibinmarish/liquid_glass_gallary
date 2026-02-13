import 'package:flutter/material.dart';

/// Simple glass container - to be replaced with LiquidGlass lens in parent
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderOpacity;
  final Color tint;
  
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.borderOpacity = 0.1,
    this.tint = const Color(0xFFFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(borderOpacity),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
