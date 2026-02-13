import 'package:flutter/material.dart';

/// Provider for managing performance-related flags to avoid race conditions 
/// on heavy rendering paths (like LiquidGlassView).
class PerformanceProvider extends ChangeNotifier {
  bool _isScrollingFast = false;
  
  /// Whether the user is currently scrolling fast
  bool get isScrollingFast => _isScrollingFast;

  /// Update the fast scrolling state
  void setScrollingFast(bool value) {
    if (_isScrollingFast != value) {
      _isScrollingFast = value;
      notifyListeners();
    }
  }
}
