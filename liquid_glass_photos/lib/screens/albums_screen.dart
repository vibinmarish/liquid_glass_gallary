import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../theme/glass_theme.dart';
import '../providers/album_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/media_index_provider.dart';
import 'album_detail_screen.dart';

/// iOS 26 style Albums screen
/// Features: List-style albums, People & Places horizontal row, New Album button
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AlbumProvider>(
      builder: (context, albumProvider, child) {
        return Stack(
          children: [
            Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header with (+) button
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'Albums',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              GlassButton(
                                onTap:
                                    () => context
                                        .read<UIProvider>()
                                        .setShowNewAlbumDialog(true),
                                icon: Icons.add,
                                width: 44,
                                height: 44,
                                iconSize: 28,
                                iconColor: GlassColors.primary,
                                shape: const LiquidOval(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (albumProvider.isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (albumProvider.albums.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No albums yet',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final album = albumProvider.albums[index];
                            return _AlbumGridCard(album: album);
                          }, childCount: albumProvider.albums.length),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
                // Scrim for Global Overlays
                Consumer<UIProvider>(
                  builder: (context, ui, _) {
                    if (ui.showNewAlbumDialog) {
                      return GestureDetector(
                        onTap: () => ui.setShowNewAlbumDialog(false),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            // Liquid Glass Dialog
            // Overlays are now handled by HomeScreen via UIProvider
          ],
        );
      },
    );
  }
}

class _AlbumGridCard extends StatelessWidget {
  final Album album;
  const _AlbumGridCard({required this.album});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
        );
      },
      onLongPress:
          !album.isSystem
              ? () {
                _showAlbumOptions(context, album, isDark);
              }
              : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            _AlbumThumbnail(album: album),

            // Bottom Vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.5, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Title & Count
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Consumer<MediaIndexProvider>(
                    builder: (context, mediaProvider, child) {
                      final count =
                          album.id == 'favorites'
                              ? mediaProvider.favoriteItems.length
                              : album.itemCount;
                      return Text(
                        '$count items',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlbumOptions(BuildContext context, Album album, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => GlassContainer(
            margin: const EdgeInsets.all(16),
            shape: const LiquidRoundedRectangle(borderRadius: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Album',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    context.read<AlbumProvider>().deleteAlbum(album);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
    );
  }
}

class _AlbumThumbnail extends StatelessWidget {
  final Album album;
  const _AlbumThumbnail({required this.album});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check favorites first
    if (album.id == 'favorites') {
      final favs = context.watch<MediaIndexProvider>().favoriteItems;
      if (favs.isNotEmpty && favs.first.asset != null) {
        return AssetEntityImage(
          favs.first.asset!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize.square(400), // Larger for grid
          fit: BoxFit.cover,
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? GlassColors.groupedDark : GlassColors.groupedLight,
      ),
      child:
          kIsWeb && album.thumbnailUrl != null
              ? Image.network(album.thumbnailUrl!, fit: BoxFit.cover)
              : (album.coverAsset != null
                  ? AssetEntityImage(
                    album.coverAsset!,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(
                      400,
                    ), // Larger for grid
                    fit: BoxFit.cover,
                  )
                  : Icon(
                    Icons.photo_library_outlined,
                    color:
                        isDark
                            ? GlassColors.textTertiaryDark
                            : GlassColors.textTertiaryLight,
                    size: 40,
                  )),
    );
  }
}
