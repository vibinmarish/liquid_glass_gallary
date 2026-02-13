import 'package:flutter/material.dart';

/// Central navigation state manager for iOS 26-style navigation
class NavigationState extends ChangeNotifier {
  int _currentTabIndex = 0;
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {};
  
  int get currentTabIndex => _currentTabIndex;
  
  /// Get or create navigator key for a tab
  GlobalKey<NavigatorState> navigatorKeyFor(int tabIndex) {
    _navigatorKeys[tabIndex] ??= GlobalKey<NavigatorState>();
    return _navigatorKeys[tabIndex]!;
  }
  
  /// Switch to a tab (preserves all state)
  void switchTab(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }
  
  /// Handle back navigation (iOS 26 style)
  /// Returns true if back was handled, false if should exit app
  bool handleBack() {
    final navigatorKey = _navigatorKeys[_currentTabIndex];
    if (navigatorKey?.currentState?.canPop() ?? false) {
      navigatorKey!.currentState!.pop();
      return true;
    }
    return false;
  }
  
  /// Push a route on the current tab's navigator
  void pushRoute(String routeName, {Object? arguments}) {
    final navigatorKey = _navigatorKeys[_currentTabIndex];
    navigatorKey?.currentState?.pushNamed(routeName, arguments: arguments);
  }
  
  /// Pop the current route
  void popRoute<T>([T? result]) {
    final navigatorKey = _navigatorKeys[_currentTabIndex];
    navigatorKey?.currentState?.pop(result);
  }
}
