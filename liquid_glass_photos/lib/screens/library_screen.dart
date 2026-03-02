import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/media_index_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/ui_provider.dart';
import '../widgets/gallery_thumbnail.dart';
import 'package:keframe/keframe.dart';
import '../state/scroll_state_manager.dart';
import '../core/config.dart';
import '../models/media_item.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/adaptive_glass_menu.dart';
import '../theme/glass_settings.dart';

class _PhotosScrollPhysics extends BouncingScrollPhysics {
  const _PhotosScrollPhysics({super.parent});

  @override
  _PhotosScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _PhotosScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get dragStartDistanceMotionThreshold => 6.0;
}

class LibraryScreen extends StatefulWidget {
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

class _LibraryScreenState extends State<LibraryScreen> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const String _screenId = 'library';
  late ScrollController _scrollController;
  final ScrollStateManager _scrollManager = ScrollStateManager();
  MediaIndexProvider? _mediaProvider;
  
  // Grid density animation
  late AnimationController _columnAnimationController;
  late Animation<double> _columnOpacity;
  
  // Grid density controlled by parent or pinch gesture
  late int _columnCount;
  
  @override
  bool get wantKeepAlive => true;
  
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ⚡️ STABILIZATION: Removed the Skia SIGSEGV fix that was swapping the widget tree.
    // Swapping between FrameSeparateWidget and raw items based on lifecycle caused
    // a visible "reload" effect when notification shades were toggled.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    
    if (_scrollController.position.extentAfter < 2500) {
      final provider = context.read<MediaIndexProvider>();
      if (provider.hasMore && !provider.isLoading) {
        provider.loadMore();
      }
    }
  }
  
  void _handlePhotoTap(int index, MediaItem item) {
    if (!mounted) return;
    
    final selection = context.read<SelectionProvider>();

    if (selection.isSelectMode) {
      selection.toggleSelection(item.id);
      HapticFeedback.selectionClick();
    } else {
      if (widget.onPhotoTap != null) widget.onPhotoTap!(index);
    }
  }

  void _handlePhotoLongPress(MediaItem item, Offset globalPosition) {
    final selection = context.read<SelectionProvider>();
    if (selection.isSelectMode) return;
    
    HapticFeedback.mediumImpact();
    context.read<UIProvider>().showContextMenu(item, globalPosition);
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final topPadding = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    

    final mediaItems = context.select<MediaIndexProvider, List<MediaItem>>((p) => p.mediaItems);
    final hasFolders = context.select<MediaIndexProvider, bool>((p) => p.hasKnownPhotos);
    final isLoading = context.select<MediaIndexProvider, bool>((p) => p.isLoading);
    final error = context.select<MediaIndexProvider, String?>((p) => p.error);

    if (mediaItems.isEmpty && !hasFolders && !isLoading) {
      return const _EmptyState();
    }
    
    if (error != null) {
      return _ErrorState(message: error);
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Bottom-most layer: solid theme background
          Container(color: Theme.of(context).scaffoldBackgroundColor),

          // Scrollable grid section
          ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(overscroll: false),
            child: SizeCacheWidget(
              child: CustomScrollView(
                controller: _scrollController,
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
                              
                              final gridChild = Selector<SelectionProvider, ({bool isSelectMode, bool isSelected})>(
                                selector: (_, s) => (
                                  isSelectMode: s.isSelectMode,
                                  isSelected: s.isSelected(item.id)
                                ),
                                builder: (context, selection, _) {
                                  final child = Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      GalleryThumbnail(asset: item.asset!),
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

                                  if (selection.isSelectMode) {
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _handlePhotoTap(index, item),
                                      child: child,
                                    );
                                  }

                                    return AdaptiveGlassMenu(
                                      menuWidth: 220,
                                      menuBorderRadius: 24,
                                      glassSettings: AppGlassSettings.menu,
                                      triggerBuilder: (context, toggleMenu) {
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _handlePhotoTap(index, item),
                                        onLongPress: () {
                                          HapticFeedback.mediumImpact();
                                          toggleMenu();
                                        },
                                        child: child,
                                      );
                                    },
                                    items: [
                                      GlassMenuItem(
                                        title: 'Share',
                                        icon: Icons.ios_share_rounded,
                                        onTap: () async {
                                          final file = await item.asset?.file;
                                          if (file != null) {
                                            await Share.shareXFiles([XFile(file.path)]);
                                          }
                                        },
                                      ),
                                      GlassMenuItem(
                                        title: 'Favorite',
                                        icon: item.isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        onTap: () {
                                          context.read<MediaIndexProvider>().toggleFavorite(item);
                                          HapticFeedback.mediumImpact();
                                        },
                                      ),
                                      GlassMenuItem(
                                        title: 'Delete',
                                        icon: Icons.delete_outline_rounded,
                                        isDestructive: true,
                                        onTap: () {
                                          context.read<UIProvider>().showDeleteConfirm(item);
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );

                              return FrameSeparateWidget(
                                index: index,
                                placeHolder: const ColoredBox(color: Color(0xFF202020)),
                                child: gridChild,
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
          
          // Top Bar (Legacy)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(context),
          ),

          // Scrim for UIProvider overlays (Context Menu & Delete Confirm)
          Consumer<UIProvider>(
            builder: (context, ui, _) {
              if (ui.contextMenuItem != null || ui.deleteConfirmItem != null) {
                return Positioned.fill(
                  child: GestureDetector(
                    onTap: () => ui.clearOverlays(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.black.withValues(alpha: 0.4)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Container(
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
                    photoCount: index.safePhotoCount, 
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
            GlassButton.custom(
              onTap: () => context.read<MediaIndexProvider>().loadMedia(),
              width: 120,
              height: 44,
              shape: const LiquidRoundedRectangle(borderRadius: 22),
              child: const Center(
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
