import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_ui.dart';

/// Glass card with highlight gradient
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool showHighlight;
  
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = GlassTokens.radiusMedium,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.showHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: GlassContainer(
        borderRadius: borderRadius,
        tint: GlassColors.glassWhite10,
        child: Container(
          decoration: BoxDecoration(
            gradient: showHighlight ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.02),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 1.0],
            ) : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Glass surface without blur (for non-overlay use)
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = GlassTokens.radiusMedium,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: borderRadius,
      tint: color ?? GlassColors.glassWhite10,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );
  }
}

/// Shimmer loading effect for glass surfaces
class GlassShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  
  const GlassShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = GlassTokens.radiusSmall,
  });

  @override
  State<GlassShimmer> createState() => _GlassShimmerState();
}

class _GlassShimmerState extends State<GlassShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(_controller);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                GlassColors.glassWhite10,
                GlassColors.glassWhite20,
                GlassColors.glassWhite10,
              ],
            ),
          ),
        );
      },
    );
  }
}
