import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../theme/glass_theme.dart';
import '../providers/media_index_provider.dart';

import '../providers/selection_provider.dart';
import '../state/scroll_state_manager.dart';
import '../widgets/glass_navigation_bar.dart';
import 'library_screen.dart';
import 'albums_screen.dart';
import 'package:photo_manager/photo_manager.dart';
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
  bool _showGridMenu = false;
  
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
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.read<MediaIndexProvider>().loadMedia();
      });
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
          onColumnCountChanged: (cols) => setState(() => _gridColumnCount = cols),
        );
      case 1:
        return const AlbumsScreen();
      default:
        return LibraryScreen(
          columnCount: _gridColumnCount,
          onPhotoTap: (mediaIndex) => _openViewer(mediaIndex),
          onSelectModeChanged: (val) {},
          onColumnCountChanged: (cols) => setState(() => _gridColumnCount = cols),
        );
    }
  }
  

  /// ⚡️ Show liquid glass styled menu for grid size selection
  void _toggleGridMenu() {
    setState(() => _showGridMenu = !_showGridMenu);
    if (_showGridMenu) HapticFeedback.mediumImpact();
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
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        // Tab Content
        Consumer<ViewerState>(
          builder: (context, viewerState, _) => Offstage(
            offstage: viewerState.isViewerOpen,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildTabContent(0),
                _buildTabContent(1),
              ],
            ),
          ),
        ),

        // Scrim for Grid Menu
        if (_showGridMenu)
          GestureDetector(
            onTap: () => setState(() => _showGridMenu = false),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.35),
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

    if (viewerState.isViewerOpen) {
      _closeViewer();
      return true;
    }

    if (_showGridMenu) {
      setState(() => _showGridMenu = false);
      return true;
    }
    
    if (selection.isSelectMode) {
      selection.setSelectMode(false);
      return true;
    }
    
    if (_selectedIndex != 0) {
      scrollManager.savePosition('tab_$_selectedIndex');
      setState(() => _selectedIndex = 0);
      scrollManager.restorePosition('tab_0');
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ⚡️ FIX: Selectors for UI visibility
    final isSelectMode = context.select<SelectionProvider, bool>((p) => p.isSelectMode);
    final isViewerOpen = context.select<ViewerState, bool>((p) => p.isViewerOpen);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (!_handleBackPress()) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: Stack(
          children: [
            LiquidGlassView(
              backgroundWidget: _buildBackgroundContent(),
              realTimeCapture: true,
              useSync: true,
              pixelRatio: 0.8,
              children: [
                // Navigation Bar - Only show if current glass is needed
                // Navigation Bar - Only show if current glass is needed
                if (!isSelectMode && !isViewerOpen)
                  LiquidGlass(
                    width: 200, 
                    height: 70, 
                    blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
                    chromaticAberration: 0.0, // User requested 0
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: RoundedRectangleShape(cornerRadius: 32),
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.bottomLeft,
                      margin: EdgeInsets.only(bottom: 25 + bottomPadding, left: 24),
                    ),
                    child: GlassNavigationBar(
                      selectedIndex: _selectedIndex,
                      onItemSelected: (index) {
                        final scrollManager = context.read<ScrollStateManager>();
                        scrollManager.savePosition('tab_$_selectedIndex');
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIndex = index);
                        scrollManager.restorePosition('tab_$index');
                      },
                    ),
                  ),
                
                if (!isSelectMode && !isViewerOpen && _selectedIndex == 0)
                  LiquidGlass(
                    width: 62,
                    height: 62,
                    blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
                    chromaticAberration: 0.0, 
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: RoundedRectangleShape(cornerRadius: 32),
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.bottomRight,
                      margin: EdgeInsets.only(bottom: 32 + bottomPadding, right: 24),
                    ),
                    child: GestureDetector(
                      onTap: _toggleGridMenu,
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 24,
                      ),
                    ),
                  ),

                // Floating Grid Size Menu
                if (_showGridMenu)
                  LiquidGlass(
                    width: 220,
                    height: 240,
                    blur: const LiquidGlassBlur(sigmaX: 15, sigmaY: 15),
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleShape(cornerRadius: 24),
                    chromaticAberration: 0.0,
                    distortion: 0.05,
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.bottomRight,
                      margin: EdgeInsets.only(bottom: 104 + bottomPadding, right: 24),
                    ),
                    child: _GridSizeMenu(
                      currentColumns: _gridColumnCount,
                      onChanged: (cols) {
                        setState(() {
                          _gridColumnCount = cols;
                          _showGridMenu = false;
                        });
                        HapticFeedback.mediumImpact();
                      },
                    ),
                  ),
              ],
            ),

            // Viewer Overlay
            Consumer<ViewerState>(
              builder: (context, viewerState, _) {
                if (!viewerState.isViewerOpen) return const SizedBox.shrink();
                
                // ⚡️ PERFORMANCE: Use surgical cache for viewer (Select to listen for updates)
                final assets = context.select<MediaIndexProvider, List<AssetEntity>>((p) => p.cachedAssets);

                if (assets.isEmpty) {
                   WidgetsBinding.instance.addPostFrameCallback((_) => _closeViewer());
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

class _GridSizeMenu extends StatelessWidget {
  final int currentColumns;
  final ValueChanged<int> onChanged;

  const _GridSizeMenu({
    required this.currentColumns,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem(
            columns: 3,
            label: '3 Columns',
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildMenuItem(
            columns: 4,
            label: '4 Columns',
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildMenuItem(
            columns: 5,
            label: '5 Columns',
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildMenuItem(
            columns: 6,
            label: '6 Columns',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required int columns,
    required String label,
  }) {
    final isSelected = currentColumns == columns;
    return InkWell(
      onTap: () => onChanged(columns),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? GlassColors.primary : Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
