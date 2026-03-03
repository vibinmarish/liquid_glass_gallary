import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:extended_image/extended_image.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/media_index_provider.dart';
import '../models/media_item.dart';
import '../theme/glass_theme.dart';
import '../theme/glass_settings.dart';
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

class _GalleryViewerState extends State<GalleryViewer>
    with SingleTickerProviderStateMixin {
  late ExtendedPageController _pageController;
  final ScrollController _filmstripController = ScrollController();

  // Data Source
  List<MediaItem> _allMedia = [];
  late int _currentIndex;

  // UI State
  bool _showControls = true;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Video Controller Pool
  final Map<String, VideoPlayerController> _controllerPool = {};

  // Progressive loading: track which pages have full-res ready
  final Set<int> _fullResReady = {};

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
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Initial filmstrip scroll + load full-res for initial page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFilmstripIndex(_currentIndex, animate: false);
      _scheduleFullResLoad(_currentIndex, delay: Duration.zero);
      // Initialize video controller if initial page is a video
      if (_allMedia.isNotEmpty &&
          _currentIndex < _allMedia.length &&
          _allMedia[_currentIndex].isVideo) {
        _preInitializeVideo(_allMedia[_currentIndex]);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoupled provider: use read + manual listener to prevent mid-swipe rebuilds
    if (widget.galleryItems != null) {
      _allMedia = widget.galleryItems!;
    } else {
      final provider = context.read<MediaIndexProvider>();
      _allMedia = provider.mediaItems;
      provider.removeListener(_onMediaListChanged);
      provider.addListener(_onMediaListChanged);
    }

    // Safety check if current index is out of bounds (e.g. after deletion)
    if (_currentIndex >= _allMedia.length) {
      if (_allMedia.isEmpty) {
        Navigator.pop(context);
      } else {
        _currentIndex = _allMedia.length - 1;
      }
    }
  }

  void _onMediaListChanged() {
    if (!mounted) return;
    final newItems = context.read<MediaIndexProvider>().mediaItems;
    if (newItems.length != _allMedia.length || !identical(newItems, _allMedia)) {
      setState(() {
        _allMedia = newItems;
        if (_currentIndex >= _allMedia.length) {
          if (_allMedia.isEmpty) {
            Navigator.pop(context);
          } else {
            _currentIndex = _allMedia.length - 1;
          }
        }
      });
    }
  }

  /// Precache full-res into Flutter's image cache, then mark ready
  void _scheduleFullResLoad(int index, {Duration delay = const Duration(milliseconds: 300)}) {
    Future.delayed(delay, () {
      if (!mounted || _currentIndex != index) return;
      if (index >= _allMedia.length) return;
      final item = _allMedia[index];
      if (item.asset == null || item.isVideo) return;

      final fullResProvider = AssetEntityImageProvider(
        item.asset!,
        isOriginal: true,
      );
      precacheImage(fullResProvider, context).then((_) {
        if (mounted && _currentIndex == index) {
          setState(() => _fullResReady.add(index));
        }
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    if (widget.galleryItems == null) {
      try {
        context.read<MediaIndexProvider>().removeListener(_onMediaListChanged);
      } catch (_) {}
    }
    _pageController.dispose();
    _filmstripController.dispose();
    _fadeController.dispose();
    for (final controller in _controllerPool.values) {
      controller.pause();
      controller.dispose();
    }
    _controllerPool.clear();
    super.dispose();
  }

  // --- Logic ---

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
    final targetOffset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2) + 20;
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
        if (!mounted) {
          controller.dispose();
          return;
        }
        _controllerPool[item.id] = controller;
        // Cleanup old
        if (_controllerPool.length > 3) {
          final keyToRemove = _controllerPool.keys.firstWhere(
            (k) => k != _currentItem.id,
          );
          _controllerPool.remove(keyToRemove)?.dispose();
        }
        // Auto-play if this is the currently focused video
        if (item.id == _currentItem.id) {
          controller.play();
        }
        // Rebuild so VideoPage and controls bar update
        setState(() {});
      }
    } catch (e) {
      // Ignored
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
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Check out this photo!');
    }
  }

  Future<void> _handleDelete() async {
    final itemToDelete = _currentItem;
    HapticFeedback.mediumImpact();

    // 1. Move UI to next item optimistically
    if (_allMedia.length > 1) {
      final nextIndex =
          _currentIndex >= _allMedia.length - 1
              ? _currentIndex - 1
              : _currentIndex + 1;
      _pageController.jumpToPage(
        nextIndex,
      ); // Jump to avoid animation glitch on delete
    } else {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context);
      }
    }

    // 2. Perform Delete
    await context.read<MediaIndexProvider>().deleteMediaItems({
      itemToDelete.id,
    });
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
      context
          .read<MediaIndexProvider>()
          .refresh(); // Ensure this method exists or trigger reload
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
      body: LiquidGlassScope.stack(
        // ⚡️ FIX: Wrap the image/video in backgroundWidget so blur works
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Main Gesture PageView
            ExtendedImageGesturePageView.builder(
              controller: _pageController,
              itemCount: _allMedia.length,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (index) {
                  // Fully dispose the previous video to release MediaCodec
                  final prevItem = _allMedia[_currentIndex];
                  if (prevItem.isVideo) {
                    _controllerPool.remove(prevItem.id)?.dispose();
                  }

                  setState(() => _currentIndex = index);
                  widget.onPageChanged?.call(index);
                  _scrollToFilmstripIndex(index);

                  // Schedule full-res load after swipe settles
                  _scheduleFullResLoad(index);

                  // Initialize current video controller (for controls bar)
                  if (_allMedia[index].isVideo) {
                    _preInitializeVideo(_allMedia[index]);
                  }

                  // Pre-load next video
                  if (index + 1 < _allMedia.length &&
                      _allMedia[index + 1].isVideo) {
                    _preInitializeVideo(_allMedia[index + 1]);
                  }
                },
                itemBuilder: (context, index) {
                  final item = _allMedia[index];
                  Widget pageChild;

                  if (item.isVideo) {
                    pageChild = _VideoPage(
                      mediaItem: item,
                      controller: _controllerPool[item.id],
                      isFocused: _currentIndex == index,
                    );
                  } else if (item.asset != null) {
                    // Progressive loading via Stack:
                    // - Bottom: 1080px thumbnail with gesture support (never changes)
                    // - Top: full-res overlay (passive, no gestures) once precached
                    final thumbnailImage = ExtendedImage(
                      image: AssetEntityImageProvider(
                        item.asset!,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(1080),
                        thumbnailFormat: ThumbnailFormat.jpeg,
                      ),
                      fit: BoxFit.contain,
                      mode: ExtendedImageMode.gesture,
                      enableMemoryCache: true,
                      clearMemoryCacheWhenDispose: false,
                      gaplessPlayback: true,
                      initGestureConfigHandler:
                          (_) => GestureConfig(
                            inPageView: true,
                            minScale: 1.0,
                            maxScale: 4.0,
                            animationMinScale: 0.7,
                            animationMaxScale: 5.0,
                            speed: 1.0,
                            inertialSpeed: 100.0,
                            initialScale: 1.0,
                            cacheGesture: true,
                          ),
                    );

                    pageChild = thumbnailImage;
                  } else {
                    pageChild = const Center(
                      child: Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.grey),
                    );
                  }

                  // Tapping is handled per-page to avoid competing with swiping
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    child: pageChild,
                  );
                },
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                    ), // Center padding
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
                            border:
                                isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child:
                                (item.asset != null)
                                    ? GalleryThumbnail(
                                      asset: item.asset!,
                                    ) // ⚡️ OPTIMIZATION: Reuses grid cache (200px) for instant load
                                    : const ColoredBox(color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 2.5. Video Controls (above filmstrip, only for videos)
            if (_currentItem.isVideo)
              Positioned(
                bottom: 158,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _VideoControlsBar(
                      controller: _controllerPool[_currentItem.id],
                    ),
                  ),
                ),
              ),
          ],
        ),

        // 3. Liquid Glass Controls (Overlay)
        content: IgnorePointer(
          ignoring: !_showControls,
          child: AdaptiveLiquidGlassLayer(
            quality: GlassQuality.premium,
            settings: AppGlassSettings.viewerHud,
            child: Stack(
            children:
                _showControls
                    ? [
                      // --- TOP BAR (Back + Metadata) ---

                      // Back Button
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 10,
                            left: 16,
                          ),
                          child: GlassIconButton(
                            size: 44,
                            iconSize: 20,
                            onPressed: _handleBack,
                            icon: CupertinoIcons.back,
                            quality: GlassQuality.premium,
                          ),
                        ),
                      ),

                      // Metadata (Top Center)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 8,
                          ),
                          child: GlassCard(
                            width: 200,
                            height: 50,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            shape: const LiquidRoundedRectangle(
                              borderRadius: 12,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentItem.asset?.title ?? 'Photo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatDate(_currentItem.createDate),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // --- BOTTOM CONTROLS ---

                      // Share (Bottom Left)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 40, left: 24),
                          child: GlassButton(
                            width: 48,
                            height: 48,
                            onTap: _handleShare,
                            icon: CupertinoIcons.share,
                            iconColor: GlassColors.accentBlue,
                            shape: const LiquidRoundedRectangle(
                              borderRadius: 24,
                            ),
                          ),
                        ),
                      ),

                      // Delete (Bottom Right)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 40, right: 24),
                          child: GlassButton(
                            width: 48,
                            height: 48,
                            onTap: _handleDelete,
                            icon: CupertinoIcons.delete,
                            iconColor: Colors.redAccent,
                            shape: const LiquidRoundedRectangle(
                              borderRadius: 24,
                            ),
                          ),
                        ),
                      ),

                      // Action Pill (Bottom Center) - Favorite & Edit
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 34),
                          child: SizedBox(
                            width: 140,
                            height: 60,
                            child: GlassButtonGroup(
                              borderRadius: 30,
                              children: [
                                Expanded(
                                  child: IconButton(
                                    icon: Icon(
                                      _currentItem.isFavorite
                                          ? CupertinoIcons.heart_fill
                                          : CupertinoIcons.heart,
                                      color:
                                          _currentItem.isFavorite
                                              ? Colors.red
                                              : Colors.white,
                                    ),
                                    onPressed: _toggleFavorite,
                                  ),
                                ),
                                if (!_currentItem.isVideo)
                                  Expanded(
                                    child: IconButton(
                                      icon: const Icon(
                                        CupertinoIcons.slider_horizontal_3,
                                        color: Colors.white,
                                      ),
                                      onPressed: _openEditor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]
                    : [],
          ),
        ),
      ),
      ),
    );
  }
}

// --- Video Page Helper ---

class _VideoPage extends StatefulWidget {
  final MediaItem mediaItem;
  final VideoPlayerController? controller;
  final bool isFocused;

  const _VideoPage({
    required this.mediaItem,
    this.controller,
    required this.isFocused,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  @override
  void didUpdateWidget(_VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto Play/Pause when focus changes
    if (widget.isFocused != oldWidget.isFocused && _isReady) {
      if (widget.isFocused) {
        widget.controller!.play();
      } else {
        widget.controller!.pause();
      }
    }

    // If a new controller arrives and we're focused, auto-play
    if (widget.controller != oldWidget.controller && _isReady && widget.isFocused) {
      widget.controller!.play();
    }
  }

  bool get _isReady =>
      widget.controller != null && widget.controller!.value.isInitialized;

  @override
  void dispose() {
    widget.controller?.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      // Thumbnail placeholder while controller is being initialized by pool
      if (widget.mediaItem.asset != null) {
        return ExtendedImage(
          image: AssetEntityImageProvider(
            widget.mediaItem.asset!,
            isOriginal: false,
          ),
          fit: BoxFit.contain,
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: widget.controller!.value.aspectRatio,
        child: VideoPlayer(widget.controller!),
      ),
    );
  }
}

// --- Video Controls Bar ---

class _VideoControlsBar extends StatefulWidget {
  final VideoPlayerController? controller;

  const _VideoControlsBar({this.controller});

  @override
  State<_VideoControlsBar> createState() => _VideoControlsBarState();
}

class _VideoControlsBarState extends State<_VideoControlsBar> {
  bool _isMuted = false;
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    _attachListener(widget.controller);
  }

  @override
  void didUpdateWidget(_VideoControlsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _detachListener(oldWidget.controller);
      _attachListener(widget.controller);
    }
  }

  @override
  void dispose() {
    _detachListener(widget.controller);
    super.dispose();
  }

  void _attachListener(VideoPlayerController? c) {
    if (c == null) return;
    c.addListener(_onVideoUpdate);
    _isMuted = c.value.volume == 0.0;
  }

  void _detachListener(VideoPlayerController? c) {
    c?.removeListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (!mounted || _isDragging) return;
    // Defer setState to avoid calling it during Flutter's layout/build phase.
    // VideoPlayerController can fire notifications from platform channels
    // at any point in the frame lifecycle.
    if (!_updateScheduled) {
      _updateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDragging) {
          _updateScheduled = false;
          setState(() {});
        }
      });
    }
  }

  void _togglePlayPause() {
    final c = widget.controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    HapticFeedback.lightImpact();
  }

  void _toggleMute() {
    final c = widget.controller;
    if (c == null) return;
    setState(() {
      _isMuted = !_isMuted;
      c.setVolume(_isMuted ? 0.0 : 1.0);
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isReady = c != null && c.value.isInitialized;

    final duration = isReady ? c.value.duration : Duration.zero;
    final position = _isDragging
        ? Duration(milliseconds: (duration.inMilliseconds * _dragValue).round())
        : (isReady ? c.value.position : Duration.zero);
    final progress = duration.inMilliseconds > 0
        ? (_isDragging ? _dragValue : position.inMilliseconds / duration.inMilliseconds)
        : 0.0;
    final isPlaying = isReady && c.value.isPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Play/Pause + Mute row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Play/Pause
                GestureDetector(
                  onTap: isReady ? _togglePlayPause : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Icon(
                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                // Mute/Unmute
                GestureDetector(
                  onTap: isReady ? _toggleMute : null,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Icon(
                      _isMuted ? CupertinoIcons.volume_off : CupertinoIcons.volume_up,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          SizedBox(
            height: 20, // constrain slider height
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbShape: SliderComponentShape.noThumb,
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withOpacity(0.3),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChangeStart: isReady
                    ? (v) {
                        _isDragging = true;
                        _dragValue = v;
                      }
                    : null,
                onChanged: isReady
                    ? (v) {
                        setState(() => _dragValue = v);
                      }
                    : null,
                onChangeEnd: isReady
                    ? (v) {
                        _isDragging = false;
                        final seekTo = Duration(
                          milliseconds: (duration.inMilliseconds * v).round(),
                        );
                        c.seekTo(seekTo);
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16), // Bottom padding
        ],
      ),
    );
  }
}
