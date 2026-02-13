import 'package:flutter/material.dart';

/// Centralized configuration for Liquid Glass Photos
class AppConfig {
  AppConfig._();

  // 📐 Grid Layout
  static const double gridSpacing = 1.5;
  static const double gridHorizontalPadding = 2.0;
  static const double appBarHeight = 75.0;
  static const int minColumns = 2;
  static const int maxColumns = 6;
  static const int defaultColumns = 4;

  // ⚡ Performance & Caching
  static const double cacheExtentFactor = 1.5; // multiplier for screen height

  // 🎨 Visuals & Animations
  static const Duration columnChangeDuration = Duration(milliseconds: 200);
  static const Duration deleteBatchDelay = Duration(milliseconds: 1000);
  static const double glassBlurSigma = 10.0;
  static const double glassOpacity = 0.1;

  // 🛡️ Scale Limits
  static const double minScale = 1.0;
  static const double maxScale = 4.0;
  static const double doubleTapScale = 2.5;
}
