import 'package:flutter/material.dart';
import '../models/media_item.dart';

/// Manages global UI states for glass overlays (context menus, confirmation dialogs).
/// This allows rendering all glass UI in a single root content layer in HomeScreen.
class UIProvider extends ChangeNotifier {
  // --- Context Menu ---
  MediaItem? _contextMenuItem;
  Offset? _contextMenuPosition;

  MediaItem? get contextMenuItem => _contextMenuItem;
  Offset? get contextMenuPosition => _contextMenuPosition;

  void showContextMenu(MediaItem item, Offset position) {
    _contextMenuItem = item;
    _contextMenuPosition = position;
    notifyListeners();
  }

  void hideContextMenu() {
    if (_contextMenuItem == null) return;
    _contextMenuItem = null;
    _contextMenuPosition = null;
    notifyListeners();
  }

  // --- Delete Confirmation ---
  MediaItem? _deleteConfirmItem;

  MediaItem? get deleteConfirmItem => _deleteConfirmItem;

  void showDeleteConfirm(MediaItem item) {
    _deleteConfirmItem = item;
    _contextMenuItem = null; // Close context menu when showing confirmation
    notifyListeners();
  }

  void hideDeleteConfirm() {
    if (_deleteConfirmItem == null) return;
    _deleteConfirmItem = null;
    notifyListeners();
  }

  // --- Dialogs ---
  bool _showNewAlbumDialog = false;

  bool get showNewAlbumDialog => _showNewAlbumDialog;

  void setShowNewAlbumDialog(bool show) {
    if (_showNewAlbumDialog == show) return;
    _showNewAlbumDialog = show;
    notifyListeners();
  }

  // --- Shared Close Helpers ---
  void clearOverlays() {
    bool changed = false;
    if (_contextMenuItem != null) {
      _contextMenuItem = null;
      _contextMenuPosition = null;
      changed = true;
    }
    if (_deleteConfirmItem != null) {
      _deleteConfirmItem = null;
      changed = true;
    }
    if (_showNewAlbumDialog) {
      _showNewAlbumDialog = false;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
