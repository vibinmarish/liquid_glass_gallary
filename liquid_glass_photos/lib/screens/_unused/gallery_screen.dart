import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../theme/glass_theme.dart';
import '../providers/media_index_provider.dart';
import '../models/media_item.dart';
import '../state/scroll_state_manager.dart';
import '../widgets/glass_card.dart';
import 'photo_detail_screen.dart';
import 'video_player_screen.dart';

enum LibraryViewMode { years, months, days, allPhotos }

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with AutomaticKeepAliveClientMixin {
  static const String _screenId = 'library';
  late ScrollController _scrollController;
  final ScrollStateManager _scrollManager = ScrollStateManager();
  LibraryViewMode _viewMode = LibraryViewMode.allPhotos;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _scrollController = _scrollManager.controllerFor(_screenId);
  }
  
  @override
  void dispose() {
    _scrollManager.savePosition(_screenId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<MediaIndexProvider>(
      builder: (context, mediaProvider, child) {
        if (mediaProvider.isLoading) {
          return const _LoadingGrid();
        }
        
        if (mediaProvider.error != null) {
          return _ErrorState(message: mediaProvider.error!);
        }
        
        if (mediaProvider.mediaItems.isEmpty) {
          return const _EmptyState();
        }
        
        return _LibraryView(
          groupedMedia: mediaProvider.groupedMedia,
          mediaItems: mediaProvider.mediaItems,
          scrollController: _scrollController,
          viewMode: _viewMode,
          onViewModeChanged: (mode) => setState(() => _viewMode = mode),
        );
      },
    );
  }
}

class _LibraryView extends StatelessWidget {
  final Map<String, List<MediaItem>> groupedMedia;
  final List<MediaItem> mediaItems;
  final ScrollController scrollController;
  final LibraryViewMode viewMode;
  final ValueChanged<LibraryViewMode> onViewModeChanged;
  
  const _LibraryView({
    required this.groupedMedia,
    required this.mediaItems,
    required this.scrollController,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columnCount = _getColumnCount(screenWidth);
    
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // iOS 26 style header with title and search
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Library',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // iOS 26 filter chips: Years, Months, Days, All Photos
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Years',
                  isSelected: viewMode == LibraryViewMode.years,
                  onTap: () => onViewModeChanged(LibraryViewMode.years),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Months',
                  isSelected: viewMode == LibraryViewMode.months,
                  onTap: () => onViewModeChanged(LibraryViewMode.months),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Days',
                  isSelected: viewMode == LibraryViewMode.days,
                  onTap: () => onViewModeChanged(LibraryViewMode.days),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All Photos',
                  isSelected: viewMode == LibraryViewMode.allPhotos,
                  onTap: () => onViewModeChanged(LibraryViewMode.allPhotos),
                ),
              ],
            ),
          ),
        ),
        
        // Grouped media with date headers
        ...groupedMedia.entries.expand((entry) => [
          // Date header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                _getDateLabel(entry.key),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          
          // Grid of media
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = entry.value[index];
                  return _MediaGridItem(item: item);
                },
                childCount: entry.value.length,
              ),
            ),
          ),
        ]),
        
        // Bottom padding for nav bar
        const SliverToBoxAdapter(
          child: SizedBox(height: 120),
        ),
      ],
    );
  }
  
  int _getColumnCount(double screenWidth) {
    switch (viewMode) {
      case LibraryViewMode.years:
        return 2;
      case LibraryViewMode.months:
        return 3;
      case LibraryViewMode.days:
        return 4;
      case LibraryViewMode.allPhotos:
        return (screenWidth / 100).clamp(3, 5).toInt();
    }
  }
  
  String _getDateLabel(String monthYear) {
    // Convert "January 2024" to relative labels
    final now = DateTime.now();
    final parts = monthYear.split(' ');
    if (parts.length != 2) return monthYear;
    
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    final monthIdx = months.indexOf(parts[0]);
    final year = int.tryParse(parts[1]) ?? now.year;
    
    if (monthIdx < 0) return monthYear;
    
    final itemDate = DateTime(year, monthIdx + 1);
    final daysDiff = now.difference(itemDate).inDays;
    
    if (daysDiff < 7) return 'Recent Days';
    if (daysDiff < 14) return 'Last Week';
    if (daysDiff < 60) return 'Last Month';
    return monthYear;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? GlassColors.primary
            : GlassColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : GlassColors.glassWhite60,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _MediaGridItem extends StatelessWidget {
  final MediaItem item;
  
  const _MediaGridItem({required this.item});

  void _openMedia(BuildContext context, List<MediaItem> allMedia) {
    if (item.isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(mediaItem: item),
        ),
      );
    } else {
      final index = allMedia.indexWhere((m) => m.id == item.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoDetailScreen(
            mediaItem: item,
            initialIndex: index >= 0 ? index : 0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Hero(
        tag: 'media_${item.id}',
        child: GestureDetector(
          onTap: () {
            final mediaProvider = context.read<MediaIndexProvider>();
            _openMedia(context, mediaProvider.mediaItems);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              if (kIsWeb && item.webUrl != null)
                Image.network(
                  item.webUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const GlassShimmer(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                     return Container(
                      color: GlassColors.surfaceContainer,
                      child: Icon(Icons.broken_image, color: GlassColors.glassWhite40),
                    );
                  },
                )
              else if (item.asset != null)
                AssetEntityImage(
                  item.asset!,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(300),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const GlassShimmer(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 0,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: GlassColors.surfaceContainer,
                      child: Icon(Icons.broken_image, color: GlassColors.glassWhite40),
                    );
                  },
                )
              else
                Container(
                  color: GlassColors.surfaceContainer,
                  child: Icon(
                    item.isVideo ? Icons.videocam : Icons.image,
                    color: GlassColors.glassWhite40,
                  ),
                ),
              
              // Video indicator
              if (item.isVideo)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                        if (item.duration != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              _formatDuration(item.duration!),
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDuration(int ms) {
    final seconds = (ms ~/ 1000) % 60;
    final minutes = (ms ~/ 60000);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 20,
      itemBuilder: (context, index) => const GlassShimmer(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 0,
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
          Icon(Icons.photo_library_outlined, size: 64, color: GlassColors.glassWhite40),
          const SizedBox(height: 16),
          Text(
            'No photos yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: GlassColors.glassWhite60,
            ),
          ),
          const SizedBox(height: 8),
          Text('Photos you take will appear here', style: TextStyle(color: GlassColors.glassWhite40)),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: GlassColors.glassWhite40),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: GlassColors.glassWhite60)),
        ],
      ),
    );
  }
}
