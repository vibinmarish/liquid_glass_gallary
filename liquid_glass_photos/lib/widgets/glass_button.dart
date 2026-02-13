import 'package:flutter/material.dart';
import '../theme/glass_theme.dart';
import 'glass_ui.dart';

/// Animated glass button with press feedback
class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final bool enabled;
  
  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius = GlassTokens.radiusMedium,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.backgroundColor,
    this.enabled = true,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: GlassTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTint = GlassColors.accentBlue.withOpacity(isDark ? 0.3 : 0.15);
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: widget.enabled ? 1.0 : 0.5,
              child: RepaintBoundary(
                child: GlassContainer(
                  borderRadius: widget.borderRadius,
                  tint: widget.backgroundColor ?? defaultTint,
                  child: Padding(
                    padding: widget.padding,
                    child: child,
                  ),
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A circular glass icon button with press feedback
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 28,
    this.color,
    this.backgroundColor,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = GlassColors.accentBlue.withOpacity(isDark ? 0.2 : 0.1);
    final defaultIconColor = isDark ? GlassColors.textPrimaryDark : GlassColors.textPrimaryLight;

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GlassContainer(
            borderRadius: widget.size * 2, // Full circle
            tint: widget.backgroundColor ?? defaultBg,
            child: Container(
              width: widget.size * 1.8,
              height: widget.size * 1.8,
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                color: widget.color ?? defaultIconColor,
                size: widget.size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
