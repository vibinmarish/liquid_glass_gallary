import 'package:flutter/foundation.dart';

/// Manages multi-selection state for the library grid.
class SelectionProvider extends ChangeNotifier {
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};

  bool get isSelectMode => _isSelectMode;
  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;

  void toggleSelectMode() {
    _isSelectMode = !_isSelectMode;
    if (!_isSelectMode) _selectedIds.clear();
    notifyListeners();
  }

  void setSelectMode(bool enabled) {
    if (_isSelectMode == enabled) return;
    _isSelectMode = enabled;
    if (!_isSelectMode) _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  bool isSelected(String id) => _selectedIds.contains(id);

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }
}
