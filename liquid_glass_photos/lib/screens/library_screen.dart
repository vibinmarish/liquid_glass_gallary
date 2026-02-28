import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../providers/media_index_provider.dart';
import '../providers/selection_provider.dart';
import '../widgets/liquid_button.dart';
import '../widgets/gallery_thumbnail.dart';
import 'package:keframe/keframe.dart';
import '../state/scroll_state_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../core/config.dart';
import '../models/media_item.dart';

/// ⚡️ SIMPLIFIED: Standard iOS bounce physics
class _PhotosScrollPhysics extends BouncingScrollPhysics {
  const _PhotosScrollPhysics({super.parent});

  @override
  _PhotosScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _PhotosScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 6.0;
}

/// iOS 26 Library screen with pinch-to-zoom grid and Select mode
/// Removed time jump bar per user request
class LibraryScreen extends StatefulWidget {
  /// Callback when photo is tapped - opens viewer overlay
  final ValueChanged<int>? onPhotoTap;

  /// Callback when select mode changes (to hide/show nav bar)
  final ValueChanged<bool>? onSelectModeChanged;
  
  /// External column count override (from parent grid size control)
  final int columnCount;
  
  /// Callback when column count changes (pinch gesture)
  final ValueChanged<int>? onColumnCountChanged;
  
  const LibraryScreen({
    super.key, 
    this.onPhotoTap, 
    this.onSelectModeChanged,
    this.columnCount = 4,
    this.onColumnCountChanged,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  static const String _screenId = 'library';
  late ScrollController _scrollController;
  final ScrollStateManager _scrollManager = ScrollStateManager();
  MediaIndexProvider? _mediaProvider;
  
  // Grid density animation
  late AnimationController _columnAnimationController;
  late Animation<double> _columnOpacity;
  
  // Grid density controlled by parent or pinch gesture
  late int _columnCount;
  
  // Context Menu
  MediaItem? _contextMenuItem;
  Offset? _contextMenuPosition;

  // Delete Confirmation
  MediaItem? _deleteConfirmItem;
  
  @override
  bool get wantKeepAlive => true;
  
  double? _appBarHeight;
  
  @override
  void initState() {
    super.initState();
    _columnCount = widget.columnCount;
    _scrollController = _scrollManager.controllerFor(_screenId);
    _scrollController.addListener(_onScroll);
    
    _columnAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _columnOpacity = CurvedAnimation(
      parent: _columnAnimationController,
      curve: Curves.easeInOut,
    );
    _columnAnimationController.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚡️ PAGINATION FIX: Listen to provider state changes
    // If a load finishes and we are still at the bottom, trigger next load immediately
    final provider = context.read<MediaIndexProvider>();
    if (_mediaProvider != provider) {
      _mediaProvider?.removeListener(_onProviderChange);
      _mediaProvider = provider;
      _mediaProvider?.addListener(_onProviderChange);
    }
  }
  
  void _onProviderChange() {
    if (!mounted) return;
    final provider = _mediaProvider;
    if (provider != null && !provider.isLoading && provider.hasMore) {
       // Check if we need to load more (user logic: stuck at bottom)
       if (_scrollController.hasClients && _scrollController.position.extentAfter < 2500) {
         provider.loadMore();
       }
    }
  }
  
  @override
  void dispose() {
    _mediaProvider?.removeListener(_onProviderChange);
    _scrollController.removeListener(_onScroll);
    _columnAnimationController.dispose();
    _scrollManager.savePosition(_screenId);
    super.dispose();
  }
  
  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ⚡️ ANIMATION: Morph effect when columns change
    if (oldWidget.columnCount != widget.columnCount) {
      _columnAnimationController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _columnCount = widget.columnCount);
        _columnAnimationController.forward();
      });
    }
  }
  
  // Infinite scroll trigger
  void _onScroll() {
    if (!mounted) return;
    
    // ⚡️ OPTIMIZATION: Aggressive prefetching
    // Trigger load when 2500px (approx 3-4 screens) from bottom to mask 6s native latency
    if (_scrollController.position.extentAfter < 2500) {
      final provider = context.read<MediaIndexProvider>();
      if (provider.hasMore && !provider.isLoading) {
        provider.loadMore();
      }
    }
  }

  // ⚡️ PERFORMANCE: Grid-level hit testing (Advanced Native Pattern)
  void _handleGridTapUp(TapUpDetails details) {
    
    final index = _getIndexFromOffset(details.localPosition);
    if (index == null) return;

    final mediaItems = context.read<MediaIndexProvider>().mediaItems;
    if (index >= mediaItems.length) return;

    final item = mediaItems[index];
    final selection = context.read<SelectionProvider>();

    if (selection.isSelectMode) {
      selection.toggleSelection(item.id);
      HapticFeedback.selectionClick();
    } else {
      if (widget.onPhotoTap != null) widget.onPhotoTap!(index);
    }
  }

  void _handleGridLongPress(LongPressStartDetails details) {
    
    final selection = context.read<SelectionProvider>();
    if (selection.isSelectMode) return;

    final index = _getIndexFromOffset(details.localPosition);
    if (index == null) return;

    final mediaItems = context.read<MediaIndexProvider>().mediaItems;
    if (index >= mediaItems.length) return;

    final item = mediaItems[index];
    
    HapticFeedback.mediumImpact();
    setState(() {
      _contextMenuItem = item;
      _contextMenuPosition = details.globalPosition;
    });
  }

  int? _getIndexFromOffset(Offset localPosition) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // ⚡️ FIX: Use computed AppBar height for precision
    final gridTop = _appBarHeight ?? AppConfig.appBarHeight;
    const gridHorizontalPadding = AppConfig.gridHorizontalPadding;
    const spacing = AppConfig.gridSpacing;
    
    final relativeY = localPosition.dy + _scrollController.offset - gridTop;
    final relativeX = localPosition.dx - gridHorizontalPadding;
    
    // If tap is above the grid (in AppBar) or outside horizontal bounds
    if (relativeY < 0 || relativeX < 0 || relativeX > screenWidth - gridHorizontalPadding * 2) {
      return null;
    }
    
    // Calculate item size exactly as SliverGrid does
    final totalSpacing = (_columnCount - 1) * spacing;
    final usableWidth = screenWidth - gridHorizontalPadding * 2 - totalSpacing;
    final itemSize = usableWidth / _columnCount;
    
    final row = relativeY ~/ (itemSize + spacing);
    final col = relativeX ~/ (itemSize + spacing);
    
    if (col >= _columnCount) return null;
    
    final index = row * _columnCount + col;
    return index;
  }

  void _toggleSelectMode() {
    final selection = context.read<SelectionProvider>();
    selection.toggleSelectMode();
    widget.onSelectModeChanged?.call(selection.isSelectMode);
  }

  Future<void> _handleShare() async {
    final selection = context.read<SelectionProvider>();
    if(selection.selectedIds.isEmpty) return;
    
    // Find media items
    final indexProvider = context.read<MediaIndexProvider>();
    final items = indexProvider.mediaItems.where((i) => selection.selectedIds.contains(i.id)).toList();
    
    if (items.isEmpty) return;
    
    final List<XFile> xFiles = [];
    
    // UI Feedback
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
      context.read<SelectionProvider>().clearSelection(); // Exit select mode or clear
      context.read<SelectionProvider>().setSelectMode(false);
    }
  }

  Future<void> _handleDeleteSelection() async {
    final selection = context.read<SelectionProvider>();
    if (selection.selectedIds.isEmpty) return;
    
    // Pessimistic delete: checks permission via provider
    await context.read<MediaIndexProvider>().deleteMediaItems(selection.selectedIds);
    selection.setSelectMode(false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ⚡️ PERFORMANCE: Surgical rebuilds start here
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenSize = MediaQuery.of(context).size;
    
    // ⚡️ FIX: Pre-compute AppBar height for hit-testing
    _appBarHeight = topPadding + AppConfig.appBarHeight;

    // We only listen to mediaItems list changes ( surgical )
    final mediaItems = context.select<MediaIndexProvider, List<MediaItem>>((p) => p.mediaItems);
    
    // Empty state - surgical check
    final isSelectMode = context.select<SelectionProvider, bool>((p) => p.isSelectMode);
    final hasFolders = context.select<MediaIndexProvider, bool>((p) => p.hasKnownPhotos);
    final isLoading = context.select<MediaIndexProvider, bool>((p) => p.isLoading);
    final error = context.select<MediaIndexProvider, String?>((p) => p.error);

    // ⚡️ FIX 5: NEVER show spinner. Always show ghost grid.
    if (mediaItems.isEmpty && !hasFolders && !isLoading) {
      return const _EmptyState();
    }
    
    if (error != null) {
      return _ErrorState(message: error);
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LiquidGlassView(
        backgroundWidget: Stack(
          children: [
            // Bottom-most layer: solid theme background
            Container(color: Theme.of(context).scaffoldBackgroundColor),

            // Scrollable grid section
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: _handleGridTapUp,
              onLongPressStart: _handleGridLongPress,
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false),
                child: SizeCacheWidget( // ⚡️ KEFRAME: Required ancestor
                  child: CustomScrollView(
                    controller: _scrollController,
                    // ⚡️ PERFORMANCE: Dynamic cache extent
                    cacheExtent: screenHeight * 1.5,
                    physics: const _PhotosScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Top bar background (Gradient Vignette)
                      const SliverAppBar(
                        pinned: true,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        toolbarHeight: AppConfig.appBarHeight,
                        flexibleSpace: _TopVignette(),
                      ),

                      // Photo grid
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        sliver: SliverFadeTransition(
                          opacity: _columnOpacity,
                          sliver: SliverGrid(
                            key: ValueKey(_columnCount),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columnCount,
                              childAspectRatio: 1.0, 
                              mainAxisSpacing: AppConfig.gridSpacing,
                              crossAxisSpacing: AppConfig.gridSpacing,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= mediaItems.length) {
                                  return const ColoredBox(color: Color(0xFF202020));
                                }
                                final item = mediaItems[index];

                                // ⚡️ PAGINATION TRIGGER
                                if (index >= mediaItems.length - 50) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    final provider = context.read<MediaIndexProvider>();
                                    if (provider.hasMore && !provider.isFetching) {
                                      provider.loadMore();
                                    }
                                  });
                                }
                                
                                // ⚡️ PERFORMANCE: Keframe Frame Budgeting
                                return FrameSeparateWidget(
                                  index: index,
                                  placeHolder: const ColoredBox(color: Color(0xFF202020)),
                                  child: Selector<SelectionProvider, ({bool isSelectMode, bool isSelected})>(
                                    selector: (_, s) => (
                                      isSelectMode: s.isSelectMode,
                                      isSelected: s.isSelected(item.id)
                                    ),
                                    builder: (context, selection, _) {
                                      // ⚡️ OPTIMIZATION: Don't rebuild thumbnail on selection change if possible
                                      // But we need to overlay selection UI.
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                           // The heavy image
                                           GalleryThumbnail(asset: item.asset!),
                                           
                                           // Selection Overlay
                                           if (selection.isSelectMode) ...[
                                             if (selection.isSelected)
                                               Container(color: Colors.black.withValues(alpha: 0.4)),
                                             Positioned(
                                               top: 6,
                                               right: 6,
                                               child: Container(
                                                 width: 22,
                                                 height: 22,
                                                 decoration: BoxDecoration(
                                                   shape: BoxShape.circle,
                                                   color: selection.isSelected 
                                                     ? Colors.blue 
                                                     : Colors.black.withValues(alpha: 0.2),
                                                   border: Border.all(
                                                     color: Colors.white, 
                                                     width: 1.5
                                                   ),
                                                 ),
                                                 child: selection.isSelected 
                                                   ? const Icon(Icons.check, color: Colors.white, size: 14)
                                                   : null,
                                               ),
                                             ),
                                           ],
                                           
                                           // ⚡️ Video Play Indicator
                                           if (item.isVideo && !selection.isSelectMode)
                                             Positioned(
                                               bottom: 4,
                                               right: 4,
                                               child: Container(
                                                 padding: const EdgeInsets.all(2),
                                                 decoration: BoxDecoration(
                                                   color: Colors.black54, 
                                                   borderRadius: BorderRadius.circular(4)
                                                 ),
                                                 child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                               ),
                                             ),
                                        ],
                                      );
                                    },
                                  ),
                                );
                              },
                              childCount: mediaItems.length,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true, 
                            ),
                          ),
                        ),
                      ),
                    
                      // Bottom padding & Loader
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            if (isLoading || (mediaItems.isNotEmpty && context.select<MediaIndexProvider, bool>((p) => p.hasMore)))
                              const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, 
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Top Bar (Legacy)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(context),
            ),

            // Scrim for Context Menu
            if (_contextMenuItem != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _contextMenuItem = null),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),
            // Scrim for Delete Confirmation
            if (_deleteConfirmItem != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _deleteConfirmItem = null),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black.withValues(alpha: 0.4)),
                ),
              ),
          ],
        ),
        realTimeCapture: true,
        children: [
          // Glass effect for the Select button
          LiquidButton(
            width: 80,
            height: 40,
            position: LiquidGlassAlignPosition(
              alignment: Alignment.topRight,
              margin: EdgeInsets.only(top: topPadding + 16, right: 16),
            ),
            child: Selector<SelectionProvider, bool>(
              selector: (_, p) => p.isSelectMode,
              builder: (context, isSelectMode, _) => GestureDetector(
                onTap: _toggleSelectMode,
                behavior: HitTestBehavior.opaque,
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

          // Context Menu Overlay
          if (_contextMenuItem != null)
            _buildContextMenuGlass(screenSize),
            
          // Delete Confirmation Overlay
          if (_deleteConfirmItem != null)
            _buildDeleteConfirmGlass(context),
            
          // Selection Toolbar (Bottom Center)
          if (isSelectMode)
            LiquidGlass(
              width: 160,
              height: 60,
              blur: const LiquidGlassBlur(sigmaX: 12, sigmaY: 12),
              chromaticAberration: 0.0,
              color: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleShape(cornerRadius: 30),
              position: LiquidGlassAlignPosition(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.only(bottom: 32 + bottomPadding),
              ),
              child: Selector<SelectionProvider, bool>(
                selector: (_, s) => s.selectedIds.isNotEmpty,
                builder: (context, hasSelection, _) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: hasSelection ? _handleShare : null,
                        icon: Icon(
                          Icons.ios_share_rounded,
                          color: hasSelection ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          size: 24,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      IconButton(
                        onPressed: hasSelection ? _handleDeleteSelection : null,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: hasSelection ? Colors.redAccent : Colors.white.withValues(alpha: 0.3),
                          size: 24,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  LiquidGlass _buildContextMenuGlass(Size screenSize) {
    final menuWidth = 280.0;
    final menuHeight = 200.0;
    final pos = _contextMenuPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);
    
    // Calculate best position
    double left = pos.dx - menuWidth / 2;
    double top = pos.dy - menuHeight - 20; // Prefer above with 20px gap
    
    // Check horizontal bounds
    if (left < 16) left = 16;
    if (left + menuWidth > screenSize.width - 16) left = screenSize.width - menuWidth - 16;
    
    // Check vertical bounds - if not enough space above, try below
    if (top < 60) {
      top = pos.dy + 20; // Below the tap point
    }
    // If still not enough space below, center vertically
    if (top + menuHeight > screenSize.height - 100) {
      top = (screenSize.height - menuHeight) / 2;
    }
    
    return LiquidGlass(
      position: LiquidGlassOffsetPosition(
        left: left,
        top: top,
      ),
      width: menuWidth,
      height: menuHeight,
      blur: const LiquidGlassBlur(sigmaX: 15, sigmaY: 15),
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleShape(cornerRadius: 24),
      chromaticAberration: 0.0,
      distortion: 0.05,
      child: _PhotoContextMenu(
        item: _contextMenuItem!,
        onShare: () async {
          final item = _contextMenuItem;
          setState(() => _contextMenuItem = null);
          if (item != null) {
            final file = await item.asset?.file;
            if (file != null) {
              await Share.shareXFiles([XFile(file.path)]);
            }
          }
        },
        onFavorite: () {
          final item = _contextMenuItem;
          setState(() => _contextMenuItem = null);
          if (item != null) {
            context.read<MediaIndexProvider>().toggleFavorite(item);
            HapticFeedback.mediumImpact();
          }
        },
        onDelete: () {
          final item = _contextMenuItem;
          setState(() {
            _contextMenuItem = null;
            _deleteConfirmItem = item;
          });
        },
      ),
    );
  }

  LiquidGlass _buildDeleteConfirmGlass(BuildContext context) {
    final dialogWidth = 280.0;
    final dialogHeight = 200.0;
    
    return LiquidGlass(
      position: LiquidGlassAlignPosition(
        alignment: Alignment.center,
      ),
      width: dialogWidth,
      height: dialogHeight,
      blur: const LiquidGlassBlur(sigmaX: 15, sigmaY: 15),
      color: Colors.white.withValues(alpha: 0.1),
      shape: RoundedRectangleShape(cornerRadius: 24),
      chromaticAberration: 0.0,
      distortion: 0.05,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(height: 10),
            const Text(
              'Delete Photo?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This photo will be moved to the trash.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _deleteConfirmItem = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Center(
                        child: Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final item = _deleteConfirmItem;
                      setState(() => _deleteConfirmItem = null);
                      if (item != null) {
                        await context.read<MediaIndexProvider>().deleteMediaItems({item.id});
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
      // height: 60, // ⚡️ FIX: Remove fixed height to prevent overflow with new text
      margin: EdgeInsets.only(top: topPadding + 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Library',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                Selector2<MediaIndexProvider, SelectionProvider, ({int photoCount, int totalCount, bool isSelectMode, int selectedCount})>(
                selector: (_, index, selection) => (
                  photoCount: index.safePhotoCount, // ⚡️ FIX: Use safePhotoCount to prevent 0-flash
                  totalCount: index.totalAssetsFound,
                  isSelectMode: selection.isSelectMode,
                  selectedCount: selection.selectedCount
                ),
                builder: (context, data, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.isSelectMode 
                        ? (data.selectedCount > 0 ? '${data.selectedCount} Selected' : 'Select Items')
                        : '${data.totalCount} Photos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    )
                  ],
                ),
              ),
              ],
            ),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

/// Dynamic vignette for status bar legibility
class _TopVignette extends StatelessWidget {
  const _TopVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// _GridThumbnail class REMOVED
// _PhotoContextMenu needs to be defined since it's used in _buildContextMenuGlass
class _PhotoContextMenu extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _PhotoContextMenu({
    required this.item,
    required this.onShare,
    required this.onFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem(context, 
            icon: Icons.share_outlined, 
            label: 'Share', 
            onTap: onShare
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildMenuItem(context, 
            icon: item.isFavorite ? Icons.favorite : Icons.favorite_border, 
            label: item.isFavorite ? 'Unfavorite' : 'Favorite', 
            onTap: onFavorite,
            iconColor: item.isFavorite ? Colors.redAccent : null
          ),
          const Divider(height: 1, color: Colors.white24),
          _buildMenuItem(context, 
            icon: Icons.delete_outline, 
            label: 'Delete', 
            onTap: onDelete,
            textColor: Colors.redAccent,
            iconColor: Colors.redAccent
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 60, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No Photos',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<MediaIndexProvider>().loadMedia(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
