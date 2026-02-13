import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/media_index_provider.dart';
import '../providers/selection_provider.dart';
import '../models/media_item.dart';
import '../theme/glass_theme.dart';
import 'edit_screen.dart';
import '../core/config.dart';

enum PhotoViewerState { idle, draggingVertical, zoomed }

/// iOS 26 Photo Viewer with Liquid Glass effect
/// Implemented as overlay (not route) for scroll preservation
class PhotoViewerOverlay extends StatefulWidget {
  final int initialIndex;
  final VoidCallback onClose;
  final ValueChanged<int> onIndexChanged;
  
  const PhotoViewerOverlay({
    super.key,
    required this.initialIndex,
    required this.onClose,
    required this.onIndexChanged,
  });

  @override
  State<PhotoViewerOverlay> createState() => _PhotoViewerOverlayState();
}

class _PhotoViewerOverlayState extends State<PhotoViewerOverlay>
    with SingleTickerProviderStateMixin {
  
  late PageController _pageController;
  late ScrollController _filmstripController;
  late int _currentIndex;
  List<MediaItem> _allMedia = [];
  
  bool _showControls = true;
  bool _isZoomed = false;
  // Pointer tracking for dismiss
  int _activePointers = 0;
  bool _isDragging = false;
  
  PhotoViewerState _viewerState = PhotoViewerState.idle;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _filmstripController = ScrollController();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    _startAutoHideTimer();
    
    // Scroll filmstrip to initial index after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToIndex(_currentIndex, animate: false);
    });
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_filmstripController.hasClients) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    const itemWidth = 32.0; // 28 width + 2*2 margin
    
    // Calculate offset to center the item
    final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2) + 20; // +20 for padding
    
    final maxScroll = _filmstripController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);
    
    if (animate) {
      _filmstripController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _filmstripController.jumpTo(clampedOffset);
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use MediaIndexProvider to get the current list of media
    _allMedia = context.watch<MediaIndexProvider>().mediaItems;
  }
  
  // Gesture Start Points
  Offset _gestureStart = Offset.zero;
  double _lastVelocity = 0.0;
  DateTime? _lastPointerMoveTime;
  
  // Use ValueNotifier for performant animations without full rebuilds
  final ValueNotifier<double> _dismissNotifier = ValueNotifier(0.0);

  // Video Controller Pool to prevent memory bloat
  final Map<String, VideoPlayerController> _controllerPool = {};
  
  @override
  void dispose() {
    _pageController.dispose();
    _filmstripController.dispose();
    _fadeController.dispose();
    _dismissNotifier.dispose();
    
    // Aggressive disposal of all pooled controllers
    for (final controller in _controllerPool.values) {
      controller.dispose();
    }
    _controllerPool.clear();
    
    super.dispose();
  }
  
  void _startAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_isDragging) {
        setState(() => _showControls = false);
      }
    });
  }
  
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startAutoHideTimer();
  }
  
  // Gesture State
  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    _gestureStart = event.position;
    
    if (_activePointers >= 2) {
      _viewerState = PhotoViewerState.zoomed;
      _resetDismiss();
    }
  }



  void _onPointerMove(PointerMoveEvent event) {
    if (_isZoomed || _viewerState == PhotoViewerState.zoomed) return; 

    final dx = (event.position.dx - _gestureStart.dx).abs();
    final dy = (event.position.dy - _gestureStart.dy).abs();

    if (_viewerState == PhotoViewerState.idle) {
      if (dy > dx && dy > 10) {
        _viewerState = PhotoViewerState.draggingVertical;
      } else if (dx > dy && dx > 10) {
        // Let PageView handle horizontal
      } else {
        return;
      }
    }

    if (_viewerState != PhotoViewerState.draggingVertical) return;

    // Track velocity manually for flick dismissal
    final now = DateTime.now();
    if (_lastPointerMoveTime != null) {
      final dt = now.difference(_lastPointerMoveTime!).inMicroseconds / 1000000.0;
      if (dt > 0) {
        _lastVelocity = event.delta.dy / dt;
      }
    }
    _lastPointerMoveTime = now;

    // Update notifier directly - NO SETSTATE
    final newDrag = _dismissNotifier.value + event.delta.dy;
    _dismissNotifier.value = newDrag;
    
    if (!_isDragging) {
      setState(() => _isDragging = true);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers--;

    if (_activePointers == 0) {
      final progress = (_dismissNotifier.value.abs() / 220).clamp(0.0, 1.0);
      final isFlick = _lastVelocity.abs() > 800;
      
      if (progress > 0.35 || isFlick) {
        _fadeController.reverse().then((_) => widget.onClose());
      } else {
        _resetDismiss();
      }
      
      _viewerState = PhotoViewerState.idle;
      _lastVelocity = 0;
    }
  }

  void _resetDismiss() {
    _dismissNotifier.value = 0;
    _lastVelocity = 0;
    
    if (_isDragging) {
      setState(() {
        _isDragging = false;
      });
    }
  }

  void _preInitializeVideo(MediaItem item) async {
    if (_controllerPool.containsKey(item.id)) return;
    if (item.asset == null) return;
    
    debugPrint('⚡️ Pre-initializing video: ${item.id}');
    try {
      final file = await item.asset!.file;
      if (file != null) {
        final controller = VideoPlayerController.file(file);
        await controller.initialize();
        _controllerPool[item.id] = controller;
        
        // Clean up pool if too large
        _cleanUpControllerPool();
      }
    } catch (e) {
      debugPrint('❌ Pre-init error: $e');
    }
  }

  void _cleanUpControllerPool() {
    // Keep only current and next video
    final activeIds = {
      _currentItem.id,
      if (_currentIndex < _allMedia.length - 1) _allMedia[_currentIndex + 1].id,
      if (_currentIndex > 0) _allMedia[_currentIndex - 1].id,
    };

    final staleIds = _controllerPool.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in staleIds) {
      debugPrint('♻️ Disposing stale video controller: $id');
      _controllerPool[id]?.dispose();
      _controllerPool.remove(id);
    }
  }

  MediaItem get _currentItem =>
      _allMedia.isNotEmpty ? _allMedia[_currentIndex] : _allMedia.first;
  
  void _toggleFavorite() {
    final indexProvider = context.read<MediaIndexProvider>();
    indexProvider.toggleFavorite(_currentItem);
    HapticFeedback.lightImpact();
  }
  
  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditScreen(mediaItem: _currentItem),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final itemToDelete = _currentItem;
    HapticFeedback.mediumImpact();
    
    // Optimistically update viewer state before provider removes it
    if (_allMedia.length <= 1) {
      widget.onClose();
    } else {
      // Move to next photo (or previous if it was the last one)
      if (_currentIndex >= _allMedia.length - 1) {
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }

    // Call provider to delete
    await context.read<MediaIndexProvider>().deleteMediaItems({itemToDelete.id});
  }
  
  void _showInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _GlassInfoSheet(mediaItem: _currentItem),
    );
  }

  String _getFileName(MediaItem item) {
    return item.asset?.title ?? 'Photo';
  }

  Future<void> _handleShare() async {
    final item = _allMedia[_currentIndex];
    if (kIsWeb) {
      if (item.webUrl != null) {
        await Share.share('Check out this photo: ${item.webUrl}');
      }
      return;
    }

    if (item.asset != null) {
      final file = await item.asset!.file;
      if (file != null) {
        await Share.shareXFiles([XFile(file.path)], text: item.asset!.title);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final month = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} $month  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_allMedia.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onClose());
      return const SizedBox();
    }

    if (_currentIndex >= _allMedia.length) {
      _currentIndex = _allMedia.length - 1;
    }
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _dismissNotifier,
        builder: (context, child) {
          final dismissProgress = (_dismissNotifier.value.abs() / 220).clamp(0.0, 1.0);
          final bgOpacity = 1.0 - (dismissProgress * 0.5);
          
          return Material(
            color: Colors.black.withAlpha((bgOpacity * 255).toInt()),
            child: child,
          );
        },
        child: LiquidGlassView(
          backgroundWidget: Stack(
            fit: StackFit.expand,
            children: [
              // Photo viewer with pointer tracking
              Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: GestureDetector(
                  onTap: _toggleControls,
                  child: AnimatedBuilder(
                    animation: _dismissNotifier,
                    builder: (context, child) {
                       final dismissProgress = (_dismissNotifier.value.abs() / 220).clamp(0.0, 1.0);
                       final scale = 1.0 - (dismissProgress * 0.1);
                       final dragOffset = _dismissNotifier.value;
                       
                       return Transform.translate(
                          offset: Offset(0, dragOffset),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                       );
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      physics: (_isZoomed || _activePointers >= 2 || _viewerState == PhotoViewerState.draggingVertical) 
                          ? const NeverScrollableScrollPhysics() 
                          : const BouncingScrollPhysics(),
                      itemCount: _allMedia.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                          _isZoomed = false; 
                        });
                        widget.onIndexChanged(index);
                        _scrollToIndex(index);
                        HapticFeedback.selectionClick();
                      },
                      itemBuilder: (context, index) {
                        final item = _allMedia[index];
                        
                        // ⚡️ PERFORMANCE: Pre-initialize next video if it exists
                        if (index == _currentIndex + 1 && item.isVideo) {
                           _preInitializeVideo(item);
                        }

                        return _PhotoPage(
                          mediaItem: item,
                          controller: item.isVideo ? _controllerPool[item.id] : null,
                          onZoomChanged: (zoomed) {
                            if (_isZoomed != zoomed) {
                              setState(() {
                                _isZoomed = zoomed;
                                if (zoomed) {
                                  _resetDismiss();
                                }
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Centered Stacked Text (Location & Date)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 60,
                right: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFileName(_allMedia[_currentIndex]),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(_allMedia[_currentIndex].createDate),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // --- FILMSTRIP REEL ---
              Positioned(
                bottom: 120 + bottomPadding,
                left: 0,
                right: 0,
                height: 42,
                child: ListView.builder(
                  controller: _filmstripController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _allMedia.length,
                  itemBuilder: (context, index) {
                    final item = _allMedia[index];
                    final isSelected = index == _currentIndex;
                    
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index, 
                          duration: const Duration(milliseconds: 300), 
                          curve: Curves.easeInOut
                        );
                      },
                      child: Container(
                        width: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                          color: Colors.white.withOpacity(0.05),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: item.asset != null 
                          ? AssetEntityImage(
                              item.asset!,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(120), // Small thumb
                              fit: BoxFit.cover,
                            )
                          : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          realTimeCapture: true, // Enable real-time see-through
          useSync: true,
          pixelRatio: 0.8,
          children: [
            // Circular Back Button
            LiquidGlass(
              width: 44,
              height: 44,
              magnification: 1.0,
              distortion: 0.1,
              position: LiquidGlassAlignPosition(
                alignment: Alignment.topLeft,
                margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16),
              ),
              blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
              color: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleShape(cornerRadius: 22),
              child: _GlassActionButton(
                icon: Icons.chevron_left, 
                onPressed: widget.onClose,
                color: GlassColors.accentBlue,
                size: 28,
              ),
            ),



            // Circular Share Button (Bottom Left)
            LiquidGlass(
              width: 44,
              height: 44,
              magnification: 1.0,
              distortion: 0.1,
              position: LiquidGlassAlignPosition(
                alignment: Alignment.bottomLeft,
                margin: EdgeInsets.only(bottom: 35 + bottomPadding, left: 24),
              ),
              blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
              color: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleShape(cornerRadius: 22),
              child: _GlassActionButton(
                icon: Icons.ios_share, 
                onPressed: _handleShare,
                color: GlassColors.accentBlue,
                size: 24,
              ),
            ),

            // Circular Delete Button (Bottom Right)
            LiquidGlass(
              width: 44,
              height: 44,
              magnification: 1.0,
              distortion: 0.1,
              position: LiquidGlassAlignPosition(
                alignment: Alignment.bottomRight,
                margin: EdgeInsets.only(bottom: 35 + bottomPadding, right: 24),
              ),
              blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
              color: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleShape(cornerRadius: 22),
              child: _GlassActionButton(
                icon: Icons.delete_outline, 
                onPressed: _handleDelete,
                color: GlassColors.accentBlue,
                size: 24,
              ),
            ),

            // --- CENTRAL ACTION PILL ---
            LiquidGlass(
              width: 140, // Smaller pill for just two icons
              height: 64,
              magnification: 1.0,
              distortion: 0.1,
              position: LiquidGlassAlignPosition(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.only(bottom: 25 + bottomPadding),
              ),
              blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
              color: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleShape(cornerRadius: 32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _GlassActionButton(
                      icon: _currentItem.isFavorite ? Icons.favorite : Icons.favorite_border, 
                      onPressed: _toggleFavorite,
                      color: GlassColors.accentBlue,
                    ),
                    _GlassActionButton(
                      icon: Icons.tune_outlined, 
                      onPressed: _openEditor,
                      color: GlassColors.accentBlue,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _GlassInfoSheet(
        mediaItem: _allMedia[_currentIndex],
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  
  const _GlassActionButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    const defaultColor = GlassColors.accentBlue;
    
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? defaultColor, size: size),
    );
  }
}

/// Single photo view with zoom
class _PhotoPage extends StatefulWidget {
  final MediaItem mediaItem;
  final VideoPlayerController? controller;
  final ValueChanged<bool>? onZoomChanged;
  
  const _PhotoPage({required this.mediaItem, this.controller, this.onZoomChanged});

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> with SingleTickerProviderStateMixin {
  final TransformationController _transformController = TransformationController();
  late AnimationController _animController;
  Animation<Matrix4>? _scaleAnimation;
  
  // ⚡️ Flutter-native: Track zoom state locally
  bool _isZoomed = false;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      if (_scaleAnimation != null) {
        _transformController.value = _scaleAnimation!.value;
      }
    });
  }
  
  @override
  void dispose() {
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }
  
  void _handleDoubleTap(TapDownDetails details) {
    final position = details.localPosition;
    final Matrix4 end;
    
    if (_isZoomed) {
      // Zoom out to identity
      end = Matrix4.identity();
    } else {
      // Zoom in to 2.5x at tap position
      const double scale = 2.5;
      end = Matrix4.identity()
        ..translate(position.dx, position.dy)
        ..scale(scale)
        ..translate(-position.dx, -position.dy);
    }
    
    _scaleAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: end,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    
    _animController.forward(from: 0.0).then((_) {
      _updateZoomState();
    });
    
    HapticFeedback.lightImpact();
  }
  
  void _updateZoomState() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final wasZoomed = _isZoomed;
    _isZoomed = scale > 1.05;
    
    // Notify parent only if state changed
    if (wasZoomed != _isZoomed) {
      widget.onZoomChanged?.call(_isZoomed);
    }
    
    // ⚡️ Flutter-native: Snap to identity when effectively unzoomed
    if (!_isZoomed && _transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    }
  }

  Widget _buildImage() {
    if (widget.mediaItem.asset == null) {
       return const Center(child: Text('Image not found', style: TextStyle(color: Colors.white54)));
    }

    return AssetEntityImage(
      widget.mediaItem.asset!,
      isOriginal: true,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
              : null,
            color: Colors.white24,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItem.isVideo) {
      return _VideoPage(mediaItem: widget.mediaItem, controller: widget.controller);
    }
    
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // Required for onDoubleTapDown to work
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        maxScale: 5.0,
        clipBehavior: Clip.none,
        // ⚡️ Flutter-native: Control panning based on zoom
        panEnabled: true,
        scaleEnabled: true,
        // ⚡️ Key fix: Use onInteractionStart/End for reliable state updates
        onInteractionStart: (_) {
          // Just started interaction - no action needed
        },
        onInteractionEnd: (_) {
          // ⚡️ Crucially - update zoom state AFTER gesture ends
          _updateZoomState();
        },
        child: Center(child: _buildImage()),
      ),
    );
  }
}

/// Dedicated Video Player page for Photo Viewer
class _VideoPage extends StatefulWidget {
  final MediaItem mediaItem;
  final VideoPlayerController? controller;
  
  const _VideoPage({required this.mediaItem, this.controller});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (kIsWeb) {
      setState(() => _isError = true);
      return;
    }

    try {
      if (widget.controller != null) {
        _videoPlayerController = widget.controller;
      } else {
        final file = await widget.mediaItem.asset?.file;
        if (file == null) {
          setState(() => _isError = true);
          return;
        }
        _videoPlayerController = VideoPlayerController.file(file);
        await _videoPlayerController!.initialize();
      }

      if (_videoPlayerController == null) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
        allowFullScreen: false,
        allowMuting: true,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: GlassColors.accentBlue,
          handleColor: GlassColors.accentBlue,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _isError = true);
    }
  }

  @override
  void dispose() {
    // ⚡️ Only dispose if we OWNED this controller (not from pool)
    if (widget.controller == null) {
      _videoPlayerController?.dispose();
    }
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text('Unable to play video', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

/// Info sheet with Liquid Glass effect
class _GlassInfoSheet extends StatefulWidget {
  final MediaItem mediaItem;
  
  const _GlassInfoSheet({required this.mediaItem});

  @override
  State<_GlassInfoSheet> createState() => _GlassInfoSheetState();
}

class _GlassInfoSheetState extends State<_GlassInfoSheet> {
  String? _fileName;
  String? _dimensions;
  String? _fileSize;
  
  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }
  
  Future<void> _loadMetadata() async {
    if (kIsWeb || widget.mediaItem.asset == null) return;
    
    try {
      final asset = widget.mediaItem.asset!;
      final file = await asset.file;
      
      if (mounted && file != null) {
        final bytes = await file.length();
        setState(() {
          _fileName = asset.title ?? 'Unknown';
          _dimensions = '${asset.width} × ${asset.height}';
          _fileSize = _formatBytes(bytes);
        });
      }
    } catch (e) {}
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return LiquidGlassView(
      backgroundWidget: const SizedBox.expand(),
      children: [
        LiquidGlass(
          width: MediaQuery.of(context).size.width,
          height: 380, // Substantial height for details
          magnification: 1.0,
          distortion: 0.1,
          distortionWidth: 40,
          position: LiquidGlassAlignPosition(alignment: Alignment.bottomCenter),
          blur: const LiquidGlassBlur(sigmaX: 35, sigmaY: 35),
          color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.15),
          shape: const RoundedRectangleShape(
            cornerRadius: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Photo Details', 
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                if (_fileName != null) _InfoRow(icon: Icons.insert_drive_file, label: 'Name', value: _fileName!),
                if (_dimensions != null) _InfoRow(icon: Icons.aspect_ratio, label: 'Dimensions', value: _dimensions!),
                if (_fileSize != null) _InfoRow(icon: Icons.sd_storage, label: 'Size', value: _fileSize!),
                _InfoRow(icon: Icons.photo, label: 'Type', value: widget.mediaItem.isVideo ? 'Video' : 'Photo'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: GlassColors.accentBlue.withOpacity(0.8), size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: onSurface.withOpacity(0.6))),
          const Spacer(),
          Text(value, style: TextStyle(color: onSurface, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
