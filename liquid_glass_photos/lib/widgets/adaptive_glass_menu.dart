import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/glass_settings.dart';

/// A version of [GlassMenu] that adds alignment support for upward expansion.
class AdaptiveGlassMenu extends StatefulWidget {
  final Widget? trigger;
  final Widget Function(BuildContext context, VoidCallback toggleMenu)? triggerBuilder;
  final List<GlassMenuItem> items;
  final double menuWidth;
  final double menuBorderRadius;
  final LiquidGlassSettings? glassSettings;
  final GlassQuality? quality;
  
  /// The horizontal and vertical alignment of the menu relative to the trigger.
  final Alignment? alignment;

  const AdaptiveGlassMenu({
    super.key,
    this.trigger,
    this.triggerBuilder,
    required this.items,
    this.menuWidth = 200,
    this.menuBorderRadius = 16.0,
    this.glassSettings,
    this.quality,
    this.alignment,
  }) : assert(trigger != null || triggerBuilder != null,
            'Either trigger or triggerBuilder must be provided');

  @override
  State<AdaptiveGlassMenu> createState() => _AdaptiveGlassMenuState();
}

class _AdaptiveGlassMenuState extends State<AdaptiveGlassMenu>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();

  late final AnimationController _animationController;
  Size? _triggerSize;
  double? _triggerBorderRadius;

  final _springDescription = const SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 24.0,
  );

  late Alignment _morphAlignment = widget.alignment ?? Alignment.topLeft;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController.unbounded(vsync: this);
    _animationController.addListener(() {
      if (mounted) setState(() {});
      if (_overlayController.isShowing &&
          _animationController.value <= 0.001 &&
          _animationController.status != AnimationStatus.forward) {
        _overlayController.hide();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _animationController.value.clamp(0.0, 1.0);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        children: [
          // Keep trigger fully visible as requested by user
          widget.triggerBuilder != null
              ? widget.triggerBuilder!(context, _toggleMenu)
              : GestureDetector(
                  onTap: _toggleMenu,
                  child: widget.trigger,
                ),
          OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: _buildMorphingOverlay,
          ),
        ],
      ),
    );
  }

  void _runSpring(double target) {
    final simulation = SpringSimulation(
      _springDescription,
      _animationController.value,
      target,
      0.0,
    );
    _animationController.animateWith(simulation);
  }

  void _toggleMenu() {
    if (_overlayController.isShowing && _animationController.value > 0.1) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    _triggerSize = renderBox.size;
    _triggerBorderRadius = _triggerSize!.height / 2;

    if (widget.alignment == null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? double.infinity;

      if (screenWidth.isFinite && position.dx > screenWidth / 2) {
        _morphAlignment = Alignment.topRight;
      } else {
        _morphAlignment = Alignment.topLeft;
      }
    } else {
      _morphAlignment = widget.alignment!;
    }

    _overlayController.show();
    _runSpring(1.0);
  }

  void _closeMenu() {
    _runSpring(0.0);
  }

  Widget _buildMorphingOverlay(BuildContext context) {
    if (_triggerSize == null) return const SizedBox.shrink();
    final value = _animationController.value.clamp(0.0, 1.0);

    return Stack(
      children: [
        if (value > 0.3)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
              child: Container(color: Colors.transparent),
            ),
          ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: _morphAlignment,
          followerAnchor: _morphAlignment,
          offset: Offset(0, _calculateSwoopOffset(value)),
          child: Material(
            type: MaterialType.transparency,
            child: _buildMorphingContainer(value),
          ),
        ),
      ],
    );
  }

  double _calculateSwoopOffset(double t) {
    final parabola = 1.0 - 4.0 * (t - 0.5) * (t - 0.5);
    final direction = (_morphAlignment.y > 0) ? -1.0 : 1.0;
    return parabola * 5.0 * direction;
  }

  double _calculateMenuHeight() {
    final itemHeights = widget.items.fold<double>(
      0.0,
      (sum, item) => sum + item.height,
    );
    return itemHeights + 16.0;
  }

  Widget _buildMorphingContainer(double value) {
    final inherited = context.dependOnInheritedWidgetOfExactType<InheritedLiquidGlass>();
    final effectiveQuality = widget.quality ?? inherited?.quality ?? GlassQuality.premium;
    final menuHeight = _calculateMenuHeight();

    final currentWidth = lerpDouble(_triggerSize!.width, widget.menuWidth, value)!;
    final currentHeight = value < 0.85
        ? lerpDouble(_triggerSize!.height, menuHeight, value)!
        : null;

    final currentBorderRadius = lerpDouble(
      _triggerBorderRadius ?? 16.0,
      widget.menuBorderRadius,
      value,
    )!;

    final menuOpacity = ((value - 0.7) / 0.3).clamp(0.0, 1.0);
    final containerOpacity = (value / 0.3).clamp(0.0, 1.0);
    
    final effectiveSettings = widget.glassSettings ?? AppGlassSettings.menu;

    return RepaintBoundary(
      child: Opacity(
        opacity: containerOpacity,
        child: GlassContainer(
          useOwnLayer: true, 
          settings: effectiveSettings,
          quality: effectiveQuality,
          allowElevation: true, // Match interactive button lighting
          width: currentWidth,
          height: currentHeight,
          shape: LiquidRoundedSuperellipse(borderRadius: currentBorderRadius),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Only show menu items as the container grows
              if (value > 0.65)
                Opacity(
                  opacity: menuOpacity,
                  child: SizedBox(
                    width: currentWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: widget.items.map((item) {
                            return GlassMenuItem(
                              key: item.key,
                              title: item.title,
                              icon: item.icon,
                              isDestructive: item.isDestructive,
                              trailing: item.trailing,
                              height: item.height,
                              onTap: () {
                                item.onTap();
                                _closeMenu();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
