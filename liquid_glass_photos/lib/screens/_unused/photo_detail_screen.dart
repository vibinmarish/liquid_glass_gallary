import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../providers/media_index_provider.dart';
import '../models/media_item.dart';
import '../theme/glass_theme.dart';
import '../theme/glass_theme.dart';
import 'edit_screen.dart';

/// iOS 26 style full-screen photo viewer
/// Features: horizontal swipe between photos, swipe-down dismiss, pinch-to-zoom,
/// tap to toggle controls, info overlay with date/location
class PhotoDetailScreen extends StatefulWidget {
  final MediaItem mediaItem;
  final int initialIndex;
  
  const PhotoDetailScreen({
    super.key, 
    required this.mediaItem,
    this.initialIndex = 0,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> 
    with TickerProviderStateMixin {
  
  // Page navigation
  late PageController _pageController;
  late int _currentIndex;
  List<MediaItem> _allMedia = [];
  
  // UI state
  bool _showControls = true;
  bool _isFavorited = false;
  
  // Swipe-to-dismiss state
  double _dragOffset = 0;
  double _dismissProgress = 0; // 0 to 1
  bool _isDragging = false;
  
  // Animation controllers
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Set immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Controls fade animation
    _controlsAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeOut,
    );
    
    // Auto-hide controls after 3 seconds
    _startAutoHideTimer();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final indexProvider = context.read<MediaIndexProvider>();
    _allMedia = indexProvider.mediaItems;
    
    // Find correct index if needed
    if (widget.initialIndex == 0 && _allMedia.isNotEmpty) {
      final index = _allMedia.indexWhere((m) => m.id == widget.mediaItem.id);
      if (index >= 0 && index != _currentIndex) {
        _currentIndex = index;
        _pageController = PageController(initialPage: index);
      }
    }
  }
  
  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _controlsAnimController.dispose();
    super.dispose();
  }
  
  void _startAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && !_isDragging) {
        _hideControls();
      }
    });
  }
  
  void _showControlsUI() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _controlsAnimController.forward();
      _startAutoHideTimer();
    }
  }
  
  void _hideControls() {
    if (_showControls) {
      _controlsAnimController.reverse().then((_) {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }
  
  void _toggleControls() {
    if (_showControls) {
      _hideControls();
    } else {
      _showControlsUI();
    }
  }
  
  // Swipe down to dismiss
  void _onVerticalDragStart(DragStartDetails details) {
    _isDragging = true;
  }
  
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _dragOffset += details.delta.dy;
      _dismissProgress = (_dragOffset.abs() / 300).clamp(0.0, 1.0);
    });
  }
  
  void _onVerticalDragEnd(DragEndDetails details) {
    _isDragging = false;
    
    final velocity = details.primaryVelocity ?? 0;
    final shouldDismiss = _dismissProgress > 0.4 || velocity.abs() > 800;
    
    if (shouldDismiss) {
      // Animate out and pop
      Navigator.of(context).pop();
    } else {
      // Spring back
      setState(() {
        _dragOffset = 0;
        _dismissProgress = 0;
      });
    }
  }
  
  MediaItem get _currentItem => 
      _allMedia.isNotEmpty ? _allMedia[_currentIndex] : widget.mediaItem;
  
  void _toggleFavorite() {
    setState(() => _isFavorited = !_isFavorited);
    HapticFeedback.lightImpact();
  }
  
  void _sharePhoto() {
    // TODO: Implement share functionality
    HapticFeedback.lightImpact();
  }
  
  void _openEditor() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => EditScreen(mediaItem: _currentItem),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
  
  void _deletePhoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlassColors.surfaceDark,
        title: const Text('Delete Photo?'),
        content: const Text('This photo will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close viewer
              // TODO: Actually delete the photo
            },
            child: Text('Delete', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );
  }
  
  void _showInfo() {
    final item = _currentItem;
    showModalBottomSheet(
      context: context,
      backgroundColor: GlassColors.surfaceDark,
      isScrollControlled: true,
      builder: (context) => _PhotoInfoSheet(mediaItem: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = 1.0 - (_dismissProgress * 0.5);
    final scale = 1.0 - (_dismissProgress * 0.1);
    
    return Scaffold(
      backgroundColor: Colors.black.withAlpha((bgOpacity * 255).toInt()),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photo viewer with gestures
          GestureDetector(
            onTap: _toggleControls,
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Transform.scale(
                scale: scale,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _allMedia.isEmpty ? 1 : _allMedia.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    HapticFeedback.selectionClick();
                  },
                  itemBuilder: (context, index) {
                    final item = _allMedia.isEmpty ? widget.mediaItem : _allMedia[index];
                    return _PhotoViewer(
                      mediaItem: item,
                      heroTag: 'media_${item.id}',
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Top controls
          FadeTransition(
            opacity: _controlsAnimation,
            child: _TopBar(
              onBack: () => Navigator.pop(context),
              onEdit: _openEditor,
              onMore: _showInfo,
            ),
          ),
          
          // Bottom info and actions
          FadeTransition(
            opacity: _controlsAnimation,
            child: _BottomBar(
              mediaItem: _currentItem,
              isFavorited: _isFavorited,
              onShare: _sharePhoto,
              onFavorite: _toggleFavorite,
              onTrash: _deletePhoto,
              onMore: _showInfo,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen photo viewer with zoom and pan
class _PhotoViewer extends StatefulWidget {
  final MediaItem mediaItem;
  final String heroTag;
  
  const _PhotoViewer({
    required this.mediaItem,
    required this.heroTag,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final TransformationController _transformController = TransformationController();
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
  
  void _handleDoubleTapDown(TapDownDetails details) {
    final position = details.localPosition;
    
    if (_transformController.value.getMaxScaleOnAxis() > 1.1) {
      // Zoom out
      _transformController.value = Matrix4.identity();
    } else {
      // Zoom in to tap position
      final matrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.5)
        ..translate(position.dx / 2.5, position.dy / 2.5);
      _transformController.value = matrix;
    }
  }

  Widget _buildImage() {
    if (widget.mediaItem.asset == null) {
      return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48));
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
    return Hero(
      tag: widget.heroTag,
      child: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: () {}, // Required to trigger onDoubleTapDown
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 1.0,
          maxScale: 5.0,
          clipBehavior: Clip.none,
          child: Center(child: _buildImage()),
        ),
      ),
    );
  }
}

/// iOS 26 style top bar with Edit and more options
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onMore;
  
  const _TopBar({
    required this.onBack,
    required this.onEdit,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(180),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              const Spacer(),
              // Edit button
              TextButton(
                onPressed: onEdit,
                child: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              // More options
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS 26 style bottom bar with date/location info and action buttons
class _BottomBar extends StatelessWidget {
  final MediaItem mediaItem;
  final bool isFavorited;
  final VoidCallback onShare;
  final VoidCallback onFavorite;
  final VoidCallback onTrash;
  final VoidCallback onMore;
  
  const _BottomBar({
    required this.mediaItem,
    required this.isFavorited,
    required this.onShare,
    required this.onFavorite,
    required this.onTrash,
    required this.onMore,
  });

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
  
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final date = mediaItem.createDate;
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withAlpha(200),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date and location info
              if (date != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(date),
                            style: TextStyle(
                              color: Colors.white.withAlpha(180),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              
              // Action buttons - iOS 26 style horizontal bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.share_outlined,
                      onTap: onShare,
                    ),
                    _ActionButton(
                      icon: isFavorited ? Icons.favorite : Icons.favorite_border,
                      onTap: onFavorite,
                      color: isFavorited ? Colors.red : null,
                    ),
                    _ActionButton(
                      icon: Icons.info_outline,
                      onTap: onMore,
                    ),
                    _ActionButton(
                      icon: Icons.delete_outline,
                      onTap: onTrash,
                    ),
                  ],
                ),
              ),
              
              // Swipe indicator line
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  
  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

/// Photo info bottom sheet
class _PhotoInfoSheet extends StatefulWidget {
  final MediaItem mediaItem;
  
  const _PhotoInfoSheet({required this.mediaItem});

  @override
  State<_PhotoInfoSheet> createState() => _PhotoInfoSheetState();
}

class _PhotoInfoSheetState extends State<_PhotoInfoSheet> {
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
    } catch (e) {
      // Ignore errors
    }
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.mediaItem.createDate;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Photo Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (date != null)
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
            ),
          
          if (_fileName != null)
            _InfoRow(icon: Icons.insert_drive_file, label: 'Name', value: _fileName!),
          
          if (_dimensions != null)
            _InfoRow(icon: Icons.aspect_ratio, label: 'Dimensions', value: _dimensions!),
          
          if (_fileSize != null)
            _InfoRow(icon: Icons.sd_storage, label: 'Size', value: _fileSize!),
          
          _InfoRow(
            icon: Icons.photo,
            label: 'Type',
            value: widget.mediaItem.isVideo ? 'Video' : 'Photo',
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: GlassColors.glassWhite60, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: GlassColors.glassWhite60)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
