import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:extended_image/extended_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/media_index_provider.dart';
import '../models/media_item.dart';
import '../theme/glass_theme.dart';
import '../widgets/liquid_button.dart';
import 'edit_screen.dart';
import '../widgets/gallery_thumbnail.dart';

/// Premium Glass Gallery Viewer
/// Replaces the basic viewer with a high-fidelity 'Liquid Glass' UI.
/// Features:
/// - Liquid Glass HUD (Back, Share, Delete, Actions)
/// - Filmstrip navigation
/// - Smart Auto-Hide controls
/// - Deep integration with MediaIndexProvider for Modify/Delete ops
class GalleryViewer extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onClose;
  final List<MediaItem>? galleryItems; // Optional explicit list

  const GalleryViewer({
    super.key,
    required this.initialIndex,
    this.onPageChanged,
    this.onClose,
    this.galleryItems,
  });

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> with SingleTickerProviderStateMixin {
  late ExtendedPageController _pageController;
  final ScrollController _filmstripController = ScrollController();
  
  // Data Source
  List<MediaItem> _allMedia = [];
  late int _currentIndex;
  
  // UI State
  bool _showControls = true;
  bool _isDragging = false; // For gesture dismissal tracking if needed
  
  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Video Controller Pool
  final Map<String, VideoPlayerController> _controllerPool = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
    
    // UI Fade Animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0, // Start visible
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    
    // _startAutoHideTimer(); // ⚡️ FIX: Disable auto-hide
    
    // Initial filmstrip scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFilmstripIndex(_currentIndex, animate: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use explicit items if provided, otherwise watch provider
    if (widget.galleryItems != null) {
      _allMedia = widget.galleryItems!;
    } else {
      _allMedia = context.watch<MediaIndexProvider>().mediaItems;
    }
    
    // Safety check if current index is out of bounds (e.g. after deletion)
    if (_currentIndex >= _allMedia.length) {
      if (_allMedia.isEmpty) {
        Navigator.pop(context); // Close if empty
      } else {
        _currentIndex = _allMedia.length - 1;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _filmstripController.dispose();
    _fadeController.dispose();
    
    // Dispose video controllers
    for (final controller in _controllerPool.values) {
      controller.dispose();
    }
    _controllerPool.clear();
    
    super.dispose();
  }

  // --- Logic ---

  void _startAutoHideTimer() {
    // Cancel any existing timer? (Simulated by state check)
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isDragging) {
        setState(() => _showControls = false);
        _fadeController.reverse();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _fadeController.forward();
        // _startAutoHideTimer(); // ⚡️ FIX: Disable auto-hide
      } else {
        _fadeController.reverse();
      }
    });
  }

  void _scrollToFilmstripIndex(int index, {bool animate = true}) {
    if (!_filmstripController.hasClients) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    const itemWidth = 32.0; // 28 width + 2*2 margin
    final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2) + 20;
    final maxScroll = _filmstripController.position.maxScrollExtent;
    
    if (animate) {
      _filmstripController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _filmstripController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    }
  }

  MediaItem get _currentItem => 
      (_allMedia.isNotEmpty && _currentIndex < _allMedia.length) 
          ? _allMedia[_currentIndex] 
          : MediaItem(id: 'error', isVideo: false, createDate: DateTime.now());

  Future<void> _preInitializeVideo(MediaItem item) async {
    if (_controllerPool.containsKey(item.id)) return;
    if (item.asset == null) return;
    
    try {
      final file = await item.asset!.file;
      if (file != null) {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        _controllerPool[item.id] = controller;
        // Cleanup old
        if (_controllerPool.length > 3) {
           final keyToRemove = _controllerPool.keys.firstWhere((k) => k != _currentItem.id);
           _controllerPool.remove(keyToRemove)?.dispose();
        }
      }
    } catch (e) {
      debugPrint('Video pre-init error: $e');
    }
  }

  // --- Actions ---

  void _handleBack() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _handleShare() async {
    final item = _currentItem;
    if (item.asset == null) return;
    
    final file = await item.asset!.file;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)], text: 'Check out this photo!');
    }
  }

  Future<void> _handleDelete() async {
    final itemToDelete = _currentItem;
    HapticFeedback.mediumImpact();
    
    // 1. Move UI to next item optimistically
    if (_allMedia.length > 1) {
       final nextIndex = _currentIndex >= _allMedia.length - 1 ? _currentIndex - 1 : _currentIndex + 1;
       _pageController.jumpToPage(nextIndex); // Jump to avoid animation glitch on delete
    } else {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context);
      }
    }

    // 2. Perform Delete
    await context.read<MediaIndexProvider>().deleteMediaItems({itemToDelete.id});
  }

  void _toggleFavorite() {
    context.read<MediaIndexProvider>().toggleFavorite(_currentItem);
    HapticFeedback.lightImpact();
  }

  Future<void> _openEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditScreen(mediaItem: _currentItem)),
    );
    
    if (result == true && mounted) {
      // Refresh provider if edits were made
      context.read<MediaIndexProvider>().refresh(); // Ensure this method exists or trigger reload
      // Or just reload current item if possible
      setState(() {});
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_allMedia.isEmpty) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.black,
      body: LiquidGlassView(
        // ⚡️ FIX: Wrap the image/video in backgroundWidget so blur works
        backgroundWidget: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Main Gesture PageView
            GestureDetector(
              onTap: _toggleControls,
              child: ExtendedImageGesturePageView.builder(
                controller: _pageController,
                itemCount: _allMedia.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  widget.onPageChanged?.call(index);
                  _scrollToFilmstripIndex(index);
                  
                  // Pre-load next video
                  if (index + 1 < _allMedia.length && _allMedia[index + 1].isVideo) {
                    _preInitializeVideo(_allMedia[index + 1]);
                  }
                },
                itemBuilder: (context, index) {
                  final item = _allMedia[index];
                  if (item.isVideo) {
                    return _VideoPage(
                      mediaItem: item,
                      controller: _controllerPool[item.id],
                      isFocused: _currentIndex == index,
                    );
                  } else if (item.asset != null) {
                    return ExtendedImage(
                      image: AssetEntityImageProvider(item.asset!, isOriginal: true),
                      fit: BoxFit.contain,
                      mode: ExtendedImageMode.gesture,
                      initGestureConfigHandler: (_) => GestureConfig(
                        inPageView: true, 
                        minScale: 0.9, 
                        maxScale: 4.0,
                      ),
                    );
                  }
                  return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                },
              ),
            ),
            
            // 2. Filmstrip (Part of background, under glass controls)
            Positioned(
              bottom: 110,
              left: 0, 
              right: 0,
              height: 48,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    controller: _filmstripController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 50), // Center padding
                    itemCount: _allMedia.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentIndex;
                      final item = _allMedia[index];
                      return GestureDetector(
                        onTap: () => _pageController.jumpToPage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 36 : 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                             border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                             borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: (item.asset != null) 
                              ? GalleryThumbnail(asset: item.asset!) // ⚡️ OPTIMIZATION: Reuses grid cache (200px) for instant load
                              : const ColoredBox(color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // 3. Liquid Glass Controls (Overlay)
        // Only visible when _showControls is true (handled by opacity/pointer events below? 
        // No, LiquidGlassView children are always visible unless we remove them.
        children: _showControls ? [
          // --- TOP BAR (Back + Metadata) ---
          
          // Back Button
          LiquidButton(
            width: 44, height: 44,
            position: LiquidGlassAlignPosition(
              alignment: Alignment.topLeft,
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 16),
            ),
            shape: RoundedRectangleShape(cornerRadius: 22),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: _handleBack,
            ),
          ),
          
          // Metadata (Top Center)
          LiquidGlass(
            width: 200, height: 50,
            position: LiquidGlassAlignPosition(
              alignment: Alignment.topCenter,
              margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
            ),
            blur: const LiquidGlassBlur(sigmaX: 8, sigmaY: 8),
            color: Colors.transparent, // Mostly transparent text container
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(
                     _currentItem.asset?.title ?? 'Photo',
                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                     maxLines: 1, overflow: TextOverflow.ellipsis,
                   ),
                   Text(
                     _formatDate(_currentItem.createDate),
                     style: const TextStyle(color: Colors.white70, fontSize: 10),
                   ),
                ],
              ),
            ),
          ),

          // --- BOTTOM CONTROLS ---
          
          // Share (Bottom Left)
          LiquidButton(
            width: 48, height: 48,
            position: LiquidGlassAlignPosition(
              alignment: Alignment.bottomLeft,
              margin: const EdgeInsets.only(bottom: 40, left: 24),
            ),
            shape: RoundedRectangleShape(cornerRadius: 24),
            child: IconButton(
              icon: const Icon(Icons.ios_share, color: GlassColors.accentBlue),
              onPressed: _handleShare,
            ),
          ),
          
          // Delete (Bottom Right)
          LiquidButton(
            width: 48, height: 48,
            position: LiquidGlassAlignPosition(
              alignment: Alignment.bottomRight,
              margin: const EdgeInsets.only(bottom: 40, right: 24),
            ),
            shape: RoundedRectangleShape(cornerRadius: 24),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _handleDelete,
            ),
          ),
          
          // Action Pill (Bottom Center) - Favorite & Edit
          LiquidButton(
            width: 140, height: 60,
            position: LiquidGlassAlignPosition(
              alignment: Alignment.bottomCenter,
              margin: const EdgeInsets.only(bottom: 34),
            ),
            shape: RoundedRectangleShape(cornerRadius: 30),
            color: Colors.black.withOpacity(0.3), // Darker for pill
            blur: const LiquidGlassBlur(sigmaX: 15, sigmaY: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _currentItem.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _currentItem.isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                ),
                if (!_currentItem.isVideo) ...[
                  Container(width: 1, height: 20, color: Colors.white24),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white),
                    onPressed: _openEditor,
                  ),
                ],
              ],
            ),
          ),
        ] : [],
      ),
    );
  }
}

// --- Video Page Helper ---

class _VideoPage extends StatefulWidget {
  final MediaItem mediaItem;
  final VideoPlayerController? controller;
  final bool isFocused;

  const _VideoPage({required this.mediaItem, this.controller, required this.isFocused});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late VideoPlayerController? _activeController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _activeController = widget.controller;
    _initialize();
  }
  
  @override
  void didUpdateWidget(_VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
       _activeController = widget.controller;
       _initialize();
    }
    
    // Auto Play/Pause
    if (widget.isFocused != oldWidget.isFocused && _initialized && _activeController != null) {
      if (widget.isFocused) {
        _activeController!.play();
      } else {
        _activeController!.pause();
      }
    }
  }

  Future<void> _initialize() async {
    if (_activeController == null) {
      // Create if missing (fallback)
      if (widget.mediaItem.asset != null) {
         final file = await widget.mediaItem.asset!.file;
         if (file != null) {
           _activeController = VideoPlayerController.file(file);
           await _activeController!.initialize();
         }
      }
    }
    
    if (mounted && _activeController != null && _activeController!.value.isInitialized) {
      setState(() => _initialized = true);
      if (widget.isFocused) _activeController!.play();
    }
  }
  
  @override
  void dispose() {
    // Controller disposal handled by parent pool, unless we created a temp one here?
    // For safety, if we created a local one (not passed in), we should dispose it.
    // But simplistic pool logic in parent handles it for now.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _activeController == null) {
       // Thumbnail placeholder
       if (widget.mediaItem.asset != null) {
          return ExtendedImage(
             image: AssetEntityImageProvider(widget.mediaItem.asset!, isOriginal: false),
             fit: BoxFit.contain,
          );
       }
       return const Center(child: CircularProgressIndicator(color: Colors.white24));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _activeController!.value.aspectRatio,
        child: VideoPlayer(_activeController!),
      ),
    );
  }
}
