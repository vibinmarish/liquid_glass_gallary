import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../theme/glass_theme.dart';
import '../providers/media_index_provider.dart';
import '../models/media_item.dart';
import '../providers/album_provider.dart';
import 'album_detail_screen.dart';

/// iOS 26 Collections screen - Memories, Pinned, Albums, People & Pets, etc.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  // View mode: uniform_small, uniform_large, default
  String _viewMode = 'default';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlbumProvider>().loadAlbums();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer2<MediaIndexProvider, AlbumProvider>(
      builder: (context, mediaProvider, albumProvider, child) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top bar
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: _CollectionsTopBar(
                onReorderTap: () => _showReorderSheet(context),
                onViewModeTap: () => _showViewModeMenu(context),
              ),
            ),
            
            // Memories section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'Memories',
                showArrow: true,
                onTap: () {},
                child: SizedBox(
                  height: 200,
                  child: _MemoriesCarousel(mediaItems: mediaProvider.mediaItems),
                ),
              ),
            ),
            
            // Pinned section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'Pinned',
                showEdit: true,
                onEditTap: () {},
                child: SizedBox(
                  height: _viewMode == 'uniform_small' ? 100 : 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _PinnedAlbumCard(
                        title: 'Favorites',
                        icon: Icons.favorite,
                        iconColor: Colors.red,
                        count: mediaProvider.mediaItems.length ~/ 4,
                        isLarge: _viewMode != 'uniform_small',
                      ),
                      const SizedBox(width: 12),
                      _PinnedAlbumCard(
                        title: 'Screenshots',
                        icon: Icons.screenshot,
                        iconColor: Colors.green,
                        count: mediaProvider.mediaItems.length ~/ 8,
                        isLarge: _viewMode != 'uniform_small',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Albums section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'Albums',
                showArrow: true,
                onTap: () {},
                child: SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: albumProvider.albums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final album = albumProvider.albums[index];
                      return _AlbumCard(album: album);
                    },
                  ),
                ),
              ),
            ),
            
            // People & Pets section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'People & Pets',
                showArrow: true,
                onTap: () {},
                child: SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _PersonCircle(name: 'Person 1'),
                      const SizedBox(width: 12),
                      _PersonCircle(name: 'Person 2'),
                      const SizedBox(width: 12),
                      _PersonCircle(name: 'Pet'),
                    ],
                  ),
                ),
              ),
            ),
            
            // Featured Photos section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'Featured Photos',
                showArrow: true,
                onTap: () {},
                child: SizedBox(
                  height: 120,
                  child: _FeaturedPhotosRow(mediaItems: mediaProvider.mediaItems),
                ),
              ),
            ),
            
            // Media Types section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'Media Types',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MediaTypeChip(icon: Icons.videocam, label: 'Videos'),
                      _MediaTypeChip(icon: Icons.gif, label: 'Animated'),
                      _MediaTypeChip(icon: Icons.slow_motion_video, label: 'Slo-mo'),
                      _MediaTypeChip(icon: Icons.timelapse, label: 'Time-lapse'),
                      _MediaTypeChip(icon: Icons.panorama, label: 'Panoramas'),
                      _MediaTypeChip(icon: Icons.screenshot, label: 'Screenshots'),
                    ],
                  ),
                ),
              ),
            ),
            
            // Utilities section
            SliverToBoxAdapter(
              child: _CollectionSection(
                title: 'Utilities',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _UtilityRow(icon: Icons.content_copy, label: 'Duplicates'),
                      _UtilityRow(icon: Icons.visibility_off, label: 'Hidden'),
                      _UtilityRow(icon: Icons.delete_outline, label: 'Recently Deleted'),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        );
      },
    );
  }
  
  void _showReorderSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    // TODO: Implement reorder sections
  }
  
  void _showViewModeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GlassColors.surfaceDark,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.grid_view, color: _viewMode == 'uniform_small' ? GlassColors.primary : null),
            title: const Text('Uniform Small'),
            onTap: () {
              setState(() => _viewMode = 'uniform_small');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.grid_on, color: _viewMode == 'uniform_large' ? GlassColors.primary : null),
            title: const Text('Uniform Large'),
            onTap: () {
              setState(() => _viewMode = 'uniform_large');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.auto_awesome_mosaic, color: _viewMode == 'default' ? GlassColors.primary : null),
            title: const Text('Default'),
            onTap: () {
              setState(() => _viewMode = 'default');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CollectionsTopBar extends StatelessWidget {
  final VoidCallback onReorderTap;
  final VoidCallback onViewModeTap;
  
  const _CollectionsTopBar({
    required this.onReorderTap,
    required this.onViewModeTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              'Collections',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onReorderTap,
              child: Text('Reorder', style: TextStyle(color: GlassColors.primary)),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: onViewModeTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showArrow;
  final bool showEdit;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;
  
  const _CollectionSection({
    required this.title,
    required this.child,
    this.showArrow = false,
    this.showEdit = false,
    this.onTap,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (showEdit)
                GestureDetector(
                  onTap: onEditTap,
                  child: Text(
                    'Edit',
                    style: TextStyle(color: GlassColors.primary),
                  ),
                ),
              if (showArrow)
                GestureDetector(
                  onTap: onTap,
                  child: Icon(Icons.chevron_right, color: GlassColors.glassWhite40),
                ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _MemoriesCarousel extends StatelessWidget {
  final List<MediaItem> mediaItems;
  
  const _MemoriesCarousel({required this.mediaItems});

  @override
  Widget build(BuildContext context) {
    if (mediaItems.isEmpty) {
      return const Center(child: Text('No memories yet'));
    }
    
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final titles = ['This Week', 'Last Month', 'This Year'];
        return _MemoryCard(
          title: titles[index % titles.length],
          mediaItems: mediaItems,
        );
      },
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final String title;
  final List<MediaItem> mediaItems;
  
  const _MemoryCard({required this.title, required this.mediaItems});

  @override
  Widget build(BuildContext context) {
    final firstItem = mediaItems.isNotEmpty ? mediaItems.first : null;
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: GlassColors.surfaceContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb && firstItem?.webUrl != null)
             Image.network(firstItem!.webUrl!, fit: BoxFit.cover)
          else if (firstItem?.asset != null)
            AssetEntityImage(
              firstItem!.asset!,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize(300, 200),
              fit: BoxFit.cover,
            )
          else
            Container(color: GlassColors.surfaceContainer),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(180)],
              ),
            ),
          ),
          
          Positioned(
            left: 16,
            bottom: 16,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedAlbumCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final int count;
  final bool isLarge;
  
  const _PinnedAlbumCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.count,
    this.isLarge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isLarge ? 150 : 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: GlassColors.surfaceContainer,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: isLarge ? 32 : 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text('$count', style: TextStyle(color: GlassColors.glassWhite60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(album: album),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: GlassColors.surfaceContainer,
            ),
            clipBehavior: Clip.antiAlias,
            child: kIsWeb && album.thumbnailUrl != null
              ? Image.network(album.thumbnailUrl!, fit: BoxFit.cover)
              : (album.assetPath != null
                  ? FutureBuilder<List<AssetEntity>>(
                      future: album.assetPath!.getAssetListRange(start: 0, end: 1),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          return AssetEntityImage(
                            snapshot.data!.first,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize(150, 150),
                            fit: BoxFit.cover,
                          );
                        }
                        return Icon(Icons.photo_album, color: GlassColors.glassWhite40);
                      },
                    )
                  : Icon(Icons.photo_album, color: GlassColors.glassWhite40)),
          ),
          const SizedBox(height: 4),
          Text(
            album.name,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PersonCircle extends StatelessWidget {
  final String name;
  
  const _PersonCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GlassColors.surfaceContainer,
          ),
          child: Icon(Icons.person, color: GlassColors.glassWhite40),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _FeaturedPhotosRow extends StatelessWidget {
  final List<MediaItem> mediaItems;
  
  const _FeaturedPhotosRow({required this.mediaItems});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: mediaItems.take(8).length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        return _FeaturedPhotoCard(item: mediaItems[index]);
      },
    );
  }
}

class _FeaturedPhotoCard extends StatelessWidget {
  final MediaItem item;
  
  const _FeaturedPhotoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: GlassColors.surfaceContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: kIsWeb && item.webUrl != null
        ? Image.network(item.webUrl!, fit: BoxFit.cover)
        : (item.asset != null
            ? AssetEntityImage(
                item.asset!,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize(150, 150),
                fit: BoxFit.cover,
              )
            : Icon(Icons.image, color: GlassColors.glassWhite40)),
    );
  }
}

class _MediaTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  
  const _MediaTypeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: GlassColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: GlassColors.glassWhite60),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _UtilityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  
  const _UtilityRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: GlassColors.glassWhite60),
      title: Text(label),
      trailing: Icon(Icons.chevron_right, color: GlassColors.glassWhite40),
      contentPadding: EdgeInsets.zero,
      onTap: () {},
    );
  }
}
