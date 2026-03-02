import 'package:flutter/material.dart';

/// Global scroll state registry - stores scroll positions per screen
/// This is the single source of truth for scroll preservation
class ScrollStateManager {
  static final ScrollStateManager _instance = ScrollStateManager._internal();
  factory ScrollStateManager() => _instance;
  ScrollStateManager._internal();

  /// Registry of scroll states by screen ID
  final Map<String, ScrollState> _states = {};

  /// Get or create a ScrollController for a screen
  ScrollController controllerFor(String screenId) {
    if (!_states.containsKey(screenId)) {
      _states[screenId] = ScrollState(
        controller: ScrollController(),
        offset: 0,
        anchorIndex: 0,
      );
    }
    return _states[screenId]!.controller;
  }

  /// Save current scroll position for a screen
  void savePosition(String screenId) {
    final state = _states[screenId];
    if (state != null && state.controller.hasClients) {
      state.offset = state.controller.offset;
    }
  }

  /// Restore scroll position for a screen
  void restorePosition(String screenId) {
    final state = _states[screenId];
    if (state != null && state.controller.hasClients) {
      // Use addPostFrameCallback to ensure widget is laid out
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (state.controller.hasClients) {
          state.controller.jumpTo(state.offset);
        }
      });
    }
  }

  /// Get stored offset without restoring
  double getOffset(String screenId) {
    return _states[screenId]?.offset ?? 0;
  }

  /// Set anchor index (for item-based scrolling)
  void setAnchorIndex(String screenId, int index) {
    final state = _states[screenId];
    if (state != null) {
      state.anchorIndex = index;
    }
  }

  /// Get anchor index
  int getAnchorIndex(String screenId) {
    return _states[screenId]?.anchorIndex ?? 0;
  }

  /// Dispose a specific screen's controller
  void dispose(String screenId) {
    final state = _states.remove(screenId);
    state?.controller.dispose();
  }

  /// Dispose all controllers (call on app shutdown)
  void disposeAll() {
    for (final state in _states.values) {
      state.controller.dispose();
    }
    _states.clear();
  }
}

/// Individual scroll state for a screen
class ScrollState {
  final ScrollController controller;
  double offset;
  int anchorIndex;

  ScrollState({
    required this.controller,
    this.offset = 0,
    this.anchorIndex = 0,
  });
}

/// App-wide state for viewer overlay
class ViewerState extends ChangeNotifier {
  bool _isViewerOpen = false;
  int _currentIndex = 0;
  String? _returnScreenId;

  bool get isViewerOpen => _isViewerOpen;
  int get currentIndex => _currentIndex;
  String? get returnScreenId => _returnScreenId;

  /// Open viewer at specific index
  void openViewer(int index, String returnScreenId) {
    _isViewerOpen = true;
    _currentIndex = index;
    _returnScreenId = returnScreenId;
    notifyListeners();
  }

  /// Close viewer and return to grid
  void closeViewer() {
    _isViewerOpen = false;
    notifyListeners();
  }

  /// Update current viewing index
  void setCurrentIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}

/// Navigation state for tabs
class NavigationState extends ChangeNotifier {
  int _currentTabIndex = 0;
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {};

  int get currentTabIndex => _currentTabIndex;

  GlobalKey<NavigatorState> navigatorKeyFor(int tabIndex) {
    if (!_navigatorKeys.containsKey(tabIndex)) {
      _navigatorKeys[tabIndex] = GlobalKey<NavigatorState>();
    }
    return _navigatorKeys[tabIndex]!;
  }

  void switchTab(int index) {
    if (_currentTabIndex != index) {
      // Save scroll position of current tab before switching
      final scrollManager = ScrollStateManager();
      scrollManager.savePosition('tab_$_currentTabIndex');

      _currentTabIndex = index;
      notifyListeners();

      // Restore scroll position of new tab
      scrollManager.restorePosition('tab_$index');
    }
  }

  /// Handle back navigation - returns true if handled
  bool handleBack() {
    final navigatorKey = _navigatorKeys[_currentTabIndex];
    if (navigatorKey?.currentState?.canPop() ?? false) {
      navigatorKey!.currentState!.pop();
      return true;
    }

    // If on non-first tab, go to first tab
    if (_currentTabIndex != 0) {
      switchTab(0);
      return true;
    }

    return false;
  }
}
