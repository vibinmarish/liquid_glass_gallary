import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../theme/glass_theme.dart';
import '../providers/album_provider.dart';
import '../providers/media_index_provider.dart';
import '../models/media_item.dart';
import '../widgets/glass_card.dart';
import '../widgets/liquid_button.dart';
import 'gallery_viewer.dart';
import 'package:share_plus/share_plus.dart';

/// iOS 26 style Album Detail screen
/// Matches Library screen features: pinch-to-zoom, select mode, overlay viewer
class AlbumDetailScreen extends StatefulWidget {
  final Album album;
  
  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  
  // Grid density
  int _columnCount = 3;
  static const int _minColumns = 2;
  static const int _maxColumns = 5;
  
  // Select mode
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};
  
  // Overlay Viewer state
  bool _showViewer = false;
  int _viewerInitialIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _loadAlbumMedia();
  }
  
  Future<void> _loadAlbumMedia() async {
    if (widget.album.id == 'favorites') {
      final favs = context.read<MediaIndexProvider>().favoriteItems;
      setState(() {
        _mediaItems = favs;
        _isLoading = false;
      });
      return;
    }

    if (kIsWeb || widget.album.assetPath == null) {
      if (kIsWeb) {
        // Mock data for web demo
        await Future.delayed(const Duration(milliseconds: 500));
        _mediaItems = List.generate(12, (index) => MediaItem(
          id: 'album_item_$index',
          isVideo: index % 4 == 0,
          webUrl: 'https://picsum.photos/seed/album_$index/400/400',
          createDate: DateTime.now().subtract(Duration(days: index)),
        ));
      }
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final assets = await widget.album.assetPath!.getAssetListRange(
        start: 0,
        end: 500,
      );
      
      final items = assets.map((asset) => MediaItem(
        id: asset.id,
        asset: asset,
        isVideo: asset.type == AssetType.video,
        duration: asset.type == AssetType.video ? asset.duration * 1000 : null,
        createDate: asset.createDateTime,
      )).toList();
      
      // Sort latest first
      items.sort((a, b) {
        final dateA = a.createDate ?? DateTime(1970);
        final dateB = b.createDate ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });
      
      if (mounted) {
        setState(() {
          _mediaItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPinchUpdate(ScaleUpdateDetails details) {
    if (details.scale > 1.2) {
      if (_columnCount > _minColumns) {
        HapticFeedback.selectionClick();
        setState(() => _columnCount--);
      }
    } else if (details.scale < 0.8) {
      if (_columnCount < _maxColumns) {
        HapticFeedback.selectionClick();
        setState(() => _columnCount++);
      }
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) _selectedIds.clear();
    });
    HapticFeedback.mediumImpact();
  }
  
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _openViewer(int index) {
    setState(() {
      _viewerInitialIndex = index;
      _showViewer = true;
    });
  }

  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.mediumImpact();
    
    final List<XFile> xFiles = [];
    for (final id in _selectedIds) {
      final item = _mediaItems.firstWhere((i) => i.id == id);
      final file = await item.asset?.file;
      if (file != null) {
        xFiles.add(XFile(file.path));
      }
    }
    
    if (xFiles.isNotEmpty) {
      await Share.shareXFiles(xFiles);
      _toggleSelectMode();
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.heavyImpact();
    
    // In a real app, this would call a provider to delete from disk/album
    // For now, let's use the provider if available for the specific album
    if (widget.album.assetPath != null) {
      await context.read<MediaIndexProvider>().deleteMediaItems(_selectedIds);
    }
    
    _toggleSelectMode();
  }

  /// Builds the content that sits behind the LiquidGlass effects
  Widget _buildBackground(double topPadding, List<MediaItem> displayItems) {
    return GestureDetector(
      onScaleUpdate: _onPinchUpdate,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar placeholder
          SliverToBoxAdapter(child: SizedBox(height: 100 + topPadding)),
          
          // Grid
          if (_isLoading && displayItems.isEmpty)
            const _LoadingGrid()
          else if (displayItems.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columnCount,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = displayItems[index];
                    return _AlbumGridItem(
                      item: item,
                      isSelectMode: _isSelectMode,
                      isSelected: _selectedIds.contains(item.id),
                      onTap: () {
                        if (_isSelectMode) {
                          _toggleSelection(item.id);
                        } else {
                          _openViewer(index);
                        }
                      },
                    );
                  },
                  childCount: displayItems.length,
                ),
              ),
            )
          else
            const _EmptyState(),
          
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indexProvider = context.watch<MediaIndexProvider>();
    final displayItems = widget.album.id == 'favorites' 
        ? indexProvider.favoriteItems 
        : _mediaItems;
    
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: !_showViewer,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showViewer) {
          setState(() => _showViewer = false);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Background & Glass Layer
            LiquidGlassView(
              backgroundWidget: _buildBackground(topPadding, displayItems),
              realTimeCapture: true,
              children: [
                // Glass effect for the back button
                if (!_showViewer)
                   LiquidGlass(
                    width: 40,
                    height: 40,
                    blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
                    chromaticAberration: 0.0,
                    color: Colors.black.withOpacity(0.1),
                    shape: const RoundedRectangleShape(cornerRadius: 20),
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.topLeft,
                      margin: EdgeInsets.only(top: topPadding + 16, left: 16),
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      ),
                    ),
                  ),

                // Glass effect for the Select button
                if (!_showViewer)
                  LiquidButton(
                    width: 80,
                    height: 40,
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.topRight,
                      margin: EdgeInsets.only(top: topPadding + 16, right: 16),
                    ),
                    child: GestureDetector(
                      onTap: _toggleSelectMode,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          _isSelectMode ? 'Cancel' : 'Select',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Selection Toolbar (Bottom)
                if (_isSelectMode && !_showViewer)
                  LiquidGlass(
                    width: 160,
                    height: 60,
                    blur: const LiquidGlassBlur(sigmaX: 12, sigmaY: 12),
                    chromaticAberration: 0.0,
                    color: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleShape(cornerRadius: 30),
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.bottomCenter,
                      margin: EdgeInsets.only(bottom: 32 + MediaQuery.of(context).padding.bottom),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ToolbarAction(
                          icon: Icons.ios_share_rounded, 
                          onTap: _selectedIds.isNotEmpty ? _shareSelected : null,
                          isEnabled: _selectedIds.isNotEmpty,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        _ToolbarAction(
                          icon: Icons.delete_outline_rounded, 
                          onTap: _selectedIds.isNotEmpty ? _deleteSelected : null,
                          isEnabled: _selectedIds.isNotEmpty,
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            // Interaction & Content Layer
            if (!_showViewer) ...[
              const _TopVignette(),
              _AlbumTopBar(
                album: widget.album,
                itemCount: displayItems.length,
                isSelectMode: _isSelectMode,
                selectedCount: _selectedIds.length,
              ),
            ],

            // Photo Viewer Overlay (Topmost)
            if (_showViewer) ...[
              Builder(
                builder: (context) {
                  return GalleryViewer(
                    galleryItems: displayItems,
                    initialIndex: _viewerInitialIndex,
                    onPageChanged: (index) => setState(() => _viewerInitialIndex = index),
                    onClose: () => setState(() => _showViewer = false),
                  );
                }
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dedicated Album Top Bar for iOS 26 style
class _AlbumTopBar extends StatelessWidget {
  final Album album;
  final int itemCount;
  final bool isSelectMode;
  final int selectedCount;
  
  const _AlbumTopBar({
    required this.album,
    required this.itemCount,
    required this.isSelectMode,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 16, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left segment placeholder for spacing with back button glass
          const SizedBox(width: 48),
          
          // Center: Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                Text(
                  isSelectMode 
                    ? (selectedCount > 0 ? '$selectedCount Selected' : 'Select Items')
                    : '$itemCount Items',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Right segment placeholder for Select button glass
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _AlbumGridItem extends StatelessWidget {
  final MediaItem item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _AlbumGridItem({
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb && item.webUrl != null)
             Image.network(item.webUrl!, fit: BoxFit.cover)
          else if (item.asset != null)
            AssetEntityImage(
              item.asset!,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(300),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: GlassColors.surfaceContainer);
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: GlassColors.surfaceContainer,
                  child: Icon(Icons.broken_image, color: GlassColors.glassWhite40),
                );
              },
            )
          else
            Container(color: GlassColors.surfaceContainer),
          
          if (item.isVideo)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
              ),
            ),
            
          if (isSelectMode)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? GlassColors.primary : Colors.black26,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();
  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Container(color: GlassColors.surfaceContainer),
        childCount: 15,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: GlassColors.glassWhite40),
            const SizedBox(height: 16),
            Text('No photos here', style: TextStyle(color: GlassColors.glassWhite60)),
          ],
        ),
      ),
    );
  }
}

/// Helper widgets for standard iOS 26 top bar layout
class _GlassPillAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassPillAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isEnabled;
  final Color? color;

  const _ToolbarAction({
    required this.icon,
    required this.onTap,
    required this.isEnabled,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: isEnabled 
            ? (color ?? Colors.white) 
            : Colors.white.withOpacity(0.3),
        size: 24,
      ),
    );
  }
}

class _TopVignette extends StatelessWidget {
  const _TopVignette();
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 140 + topPadding,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.1),
                Colors.transparent,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
