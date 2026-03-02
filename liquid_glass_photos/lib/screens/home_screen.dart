import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../widgets/adaptive_glass_menu.dart';
import '../theme/glass_theme.dart';
import '../theme/glass_settings.dart';
import '../providers/media_index_provider.dart';

import '../providers/selection_provider.dart';
import '../providers/ui_provider.dart';
import '../widgets/glass_overlays.dart';
import '../state/scroll_state_manager.dart';
import 'library_screen.dart';
import 'albums_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'gallery_viewer.dart';
import '../core/config.dart';

/// iOS 26 Photos App Home Screen
/// 2 tabs: Library, Albums (removed Search & Utilities)
/// Uses Stack-based viewer overlay for perfect scroll preservation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _gridColumnCount = AppConfig.defaultColumns;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize media provider and start change notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaIndexProvider>().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ⚡️ PERFORMANCE: Only check for media changes on resume if absolutely necessary.
      // We already have PhotoManager.addChangeCallback in initialize() which handles 
      // real-time updates. Removing the aggressive loadMedia(showLoadingIndicator: false)
      // here prevents the grid from resetting when notification shades are toggled.
    }
  }

  // No longer need _onViewerStateChanged as we'll use Consumer/Watch

  /// Build tab content - 2 tabs only
  Widget _buildTabContent(int index) {
    switch (index) {
      case 0:
        return LibraryScreen(
          columnCount: _gridColumnCount,
          onPhotoTap: (mediaIndex) => _openViewer(mediaIndex),
          onSelectModeChanged: (val) {},
          onColumnCountChanged:
              (cols) => setState(() => _gridColumnCount = cols),
        );
      case 1:
        return const AlbumsScreen();
      default:
        return LibraryScreen(
          columnCount: _gridColumnCount,
          onPhotoTap: (mediaIndex) => _openViewer(mediaIndex),
          onSelectModeChanged: (val) {},
          onColumnCountChanged:
              (cols) => setState(() => _gridColumnCount = cols),
        );
    }
  }

  /// Open photo viewer as overlay (not route push)
  void _openViewer(int mediaIndex) {
    context.read<ScrollStateManager>().savePosition('library_grid');
    context.read<ViewerState>().openViewer(mediaIndex, 'library_grid');
  }

  /// Close viewer overlay
  void _closeViewer() {
    context.read<ViewerState>().closeViewer();
  }

  Widget _buildBackgroundContent() {
    return Stack(
      children: [
        // Solid background
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        // Tab Content (raw — glass refracts through this)
        Consumer<ViewerState>(
          builder:
              (context, viewerState, _) => Offstage(
                offstage: viewerState.isViewerOpen,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [_buildTabContent(0), _buildTabContent(1)],
                ),
              ),
        ),
      ],
    );
  }

  /// Handle back button press
  bool _handleBackPress() {
    final selection = context.read<SelectionProvider>();
    final viewerState = context.read<ViewerState>();
    final scrollManager = context.read<ScrollStateManager>();
    final ui = context.read<UIProvider>();

    // 1. Close overlays first
    if (ui.contextMenuItem != null ||
        ui.deleteConfirmItem != null ||
        ui.showNewAlbumDialog) {
      ui.clearOverlays();
      return true;
    }

    // 2. Close viewer
    if (viewerState.isViewerOpen) {
      _closeViewer();
      return true;
    }

    // 3. De-select
    if (selection.isSelectMode) {
      selection.setSelectMode(false);
      return true;
    }

    // 4. Return to Library tab
    if (_selectedIndex != 0) {
      scrollManager.savePosition('tab_$_selectedIndex');
      setState(() => _selectedIndex = 0);
      scrollManager.restorePosition('tab_0');
      return true;
    }
    return false;
  }

  void _handleToggleSelectMode() {
    final selection = context.read<SelectionProvider>();
    selection.toggleSelectMode();
    HapticFeedback.mediumImpact();
  }

  Future<void> _handleShare() async {
    final selection = context.read<SelectionProvider>();
    if (selection.selectedIds.isEmpty) return;

    final indexProvider = context.read<MediaIndexProvider>();
    final items =
        indexProvider.mediaItems
            .where((i) => selection.selectedIds.contains(i.id))
            .toList();
    if (items.isEmpty) return;

    final List<XFile> xFiles = [];
    HapticFeedback.mediumImpact();

    for (final item in items) {
      final file = await item.asset?.file;
      if (file != null) {
        xFiles.add(XFile(file.path));
      }
    }

    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(xFiles);
      if (!mounted) return;
      context.read<SelectionProvider>().clearSelection();
      context.read<SelectionProvider>().setSelectMode(false);
    }
  }

  Future<void> _handleDeleteSelection() async {
    final selection = context.read<SelectionProvider>();
    if (selection.selectedIds.isEmpty) return;

    await context.read<MediaIndexProvider>().deleteMediaItems(
      selection.selectedIds,
    );
    selection.setSelectMode(false);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔍 DIAGNOSTIC: Check rendering capabilities on each device
    debugPrint('🔍 Impeller shader support: ${ui.ImageFilter.isShaderFilterSupported}');
    debugPrint('🔍 Device Pixel Ratio: ${MediaQuery.of(context).devicePixelRatio}');
    debugPrint('🔍 Screen size: ${MediaQuery.of(context).size}');

    // ⚡️ FIX: Selectors for UI visibility
    final isSelectMode = context.select<SelectionProvider, bool>(
      (p) => p.isSelectMode,
    );
    final hasSelection = context.select<SelectionProvider, bool>(
      (p) => p.selectedIds.isNotEmpty,
    );
    final isViewerOpen = context.select<ViewerState, bool>(
      (p) => p.isViewerOpen,
    );
    final hasOverlay = context.select<UIProvider, bool>(
      (p) =>
          p.contextMenuItem != null ||
          p.deleteConfirmItem != null ||
          p.showNewAlbumDialog,
    );

    return PopScope(
      // ⚡️ PERFORMANCE: Allow standard system backgrounding if we're at the root of the app.
      // If we're on the main library tab with no selection/viewer open, we allow the OS
      // to handle the back press (which usually backgrounds the activity on modern Android).
      canPop:
          !isViewerOpen && !isSelectMode && _selectedIndex == 0 && !hasOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Manual handling for non-root states
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: Stack(
          children: [
            LiquidGlassScope.stack(
              background: _buildBackgroundContent(),
              content: Stack(
                children: [
                  // Root glass layer — bottom bar, select button, overlays, toolbar
                  AdaptiveLiquidGlassLayer(
                    quality: GlassQuality.premium,
                    settings: AppGlassSettings.bottomBar,
                    child: Stack(
                      children: [
                        // Select Button (Global)
                        if (!isViewerOpen && _selectedIndex == 0)
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: topPadding + 16,
                                right: 16,
                              ),
                                child: GlassButton.custom(
                                  width: 80,
                                  height: 40,
                                  onTap: _handleToggleSelectMode,
                                  shape: const LiquidRoundedRectangle(
                                    borderRadius: 20,
                                  ),
                                  child: Center(
                                    child: Text(
                                      isSelectMode ? 'Cancel' : 'Select',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ),
                          ),

                        // Global Overlays (Context Menu, Delete Confirm, New Album)
                        Consumer<UIProvider>(
                          builder: (context, ui, _) {
                            return Stack(
                              children: [
                                if (ui.contextMenuItem != null &&
                                    ui.contextMenuPosition != null)
                                  ContextMenuOverlay(
                                    item: ui.contextMenuItem!,
                                    position: ui.contextMenuPosition!,
                                    screenSize: MediaQuery.of(context).size,
                                  ),
                                if (ui.deleteConfirmItem != null)
                                  DeleteConfirmOverlay(
                                    item: ui.deleteConfirmItem!,
                                  ),
                                if (ui.showNewAlbumDialog)
                                  const NewAlbumDialogOverlay(),
                              ],
                            );
                          },
                        ),

                        // 1. Navigation Bar (Sharing Layer)
                        if (!isSelectMode && !isViewerOpen)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: 25 + bottomPadding,
                                left: 16,
                              ),
                              child: SizedBox(
                                width: 200,
                                child: GlassBottomBar(
                                  useOwnLayer: false,
                                  barHeight: 70,
                                  verticalPadding: 0,
                                  horizontalPadding: 0,
                                  barBorderRadius: 32,
                                  selectedIconColor: GlassColors.primary,
                                  unselectedIconColor: const Color(0xE6FFFFFF),
                                  tabs: const [
                                    GlassBottomBarTab(
                                      label: 'Library',
                                      icon: Icons.photo_library_outlined,
                                      selectedIcon: Icons.photo_library,
                                    ),
                                    GlassBottomBarTab(
                                      label: 'Albums',
                                      icon: Icons.photo_album_outlined,
                                      selectedIcon: Icons.photo_album,
                                    ),
                                  ],
                                  selectedIndex: _selectedIndex,
                                  onTabSelected: (index) {
                                    final scrollManager =
                                        context.read<ScrollStateManager>();
                                    scrollManager.savePosition(
                                      'tab_$_selectedIndex',
                                    );
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedIndex = index);
                                    scrollManager.restorePosition('tab_$index');
                                  },
                                ),
                              ),
                            ),
                          ),

                        // 2. Selection Toolbar (Sharing Layer)
                        if (isSelectMode && !isViewerOpen)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: 32 + bottomPadding,
                              ),
                              child: GlassContainer(
                                width: 140,
                                height: 64,
                                useOwnLayer: true,
                                quality: GlassQuality.premium,
                                settings: AppGlassSettings.menu,
                                shape: const LiquidRoundedSuperellipse(
                                  borderRadius: 32,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GlassIconButton(
                                      onPressed:
                                          hasSelection ? _handleShare : null,
                                      icon: Icons.ios_share_rounded,
                                      size: 44,
                                      iconSize: 24,
                                      quality: GlassQuality.premium,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 24,
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    GlassIconButton(
                                      onPressed:
                                          hasSelection
                                              ? _handleDeleteSelection
                                              : null,
                                      icon: Icons.delete_outline_rounded,
                                      size: 44,
                                      iconSize: 24,
                                      glowColor: Colors.redAccent,
                                      quality: GlassQuality.premium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Grid Size Menu — separate glass layer to prevent
                  // bottom bar flicker when the menu toggles
                  if (!isSelectMode &&
                      !isViewerOpen &&
                      _selectedIndex == 0)
                    AdaptiveLiquidGlassLayer(
                      quality: GlassQuality.premium,
                      settings: AppGlassSettings.bottomBar,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: 25 + bottomPadding,
                            right: 16,
                          ),
                              child: AdaptiveGlassMenu(
                                alignment: Alignment.bottomRight,
                                menuWidth: 220,
                                menuBorderRadius: 24,
                                glassSettings: AppGlassSettings.menu,
                                triggerBuilder: (context, toggleMenu) {
                              return GlassButton(
                                width: 70,
                                height: 70,
                                icon: Icons.grid_view_rounded,
                                iconColor:
                                    isDark ? Colors.white : Colors.black87,
                                onTap: toggleMenu,
                                shape: const LiquidRoundedSuperellipse(
                                  borderRadius: 35,
                                ),
                              );
                            },
                            items: [
                              for (int i = 3; i <= 6; i++)
                                GlassMenuItem(
                                  title: '$i Columns',
                                  icon:
                                      _gridColumnCount == i
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                  onTap: () {
                                    setState(() => _gridColumnCount = i);
                                    HapticFeedback.mediumImpact();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Viewer Overlay
            Consumer<ViewerState>(
              builder: (context, viewerState, _) {
                if (!viewerState.isViewerOpen) return const SizedBox.shrink();

                // ⚡️ PERFORMANCE: Use surgical cache for viewer (Select to listen for updates)
                final assets = context
                    .select<MediaIndexProvider, List<AssetEntity>>(
                      (p) => p.cachedAssets,
                    );

                if (assets.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _closeViewer(),
                  );
                  return const SizedBox.shrink();
                }

                // ⚡️ PERFORMANCE: Viewer now manages its own data link to MediaIndexProvider
                return GalleryViewer(
                  initialIndex: viewerState.currentIndex,
                  onPageChanged: (index) => viewerState.setCurrentIndex(index),
                  onClose: _closeViewer,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
