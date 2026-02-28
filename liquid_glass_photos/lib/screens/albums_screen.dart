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
import 'album_detail_screen.dart';

/// iOS 26 style Albums screen
/// Features: List-style albums, People & Places horizontal row, New Album button
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  bool _showNewAlbumDialog = false;
  final _albumNameController = TextEditingController();
  
  @override
  void dispose() {
    _albumNameController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlbumProvider>().loadAlbums();
    });
  }

  void _toggleCreateAlbumDialog() {
    setState(() {
      _showNewAlbumDialog = !_showNewAlbumDialog;
      if (_showNewAlbumDialog) {
        _albumNameController.clear();
        HapticFeedback.mediumImpact();
      }
    });
  }

  void _saveAlbum() {
    if (_albumNameController.text.isNotEmpty) {
      context.read<AlbumProvider>().createAlbum(_albumNameController.text);
      setState(() => _showNewAlbumDialog = false);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<AlbumProvider>(
      builder: (context, albumProvider, child) {
        return LiquidGlassView(
          realTimeCapture: true,
          useSync: true,
          pixelRatio: 0.8,
          backgroundWidget: Stack(
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
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: _toggleCreateAlbumDialog,
                              icon: const Icon(Icons.add, color: GlassColors.primary, size: 28),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  
                  if (albumProvider.isLoading)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  else if (albumProvider.albums.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No albums yet', 
                            style: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final album = albumProvider.albums[index];
                            return _AlbumGridCard(album: album);
                          },
                          childCount: albumProvider.albums.length,
                        ),
                      ),
                    ),
                  
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              // Scrim
              if (_showNewAlbumDialog)
                GestureDetector(
                  onTap: () => setState(() => _showNewAlbumDialog = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
          children: [
            // Liquid Glass Dialog
            if (_showNewAlbumDialog)
              LiquidGlass(
                width: 320,
                height: 250,
                blur: const LiquidGlassBlur(sigmaX: 20, sigmaY: 20),
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2),
                chromaticAberration: 0.0,
                shape: RoundedRectangleShape(cornerRadius: 32),
                position: const LiquidGlassAlignPosition(
                  alignment: Alignment.center,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'New Album',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _albumNameController,
                        autofocus: true,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Album Name',
                          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _showNewAlbumDialog = false),
                            child: const Text('Cancel', style: TextStyle(color: GlassColors.accentBlue, fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _saveAlbum,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassColors.accentBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
      onLongPress: !album.isSystem ? () {
        _showAlbumOptions(context, album, isDark);
      } : null,
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
                      final count = album.id == 'favorites' ? mediaProvider.favoriteItems.length : album.itemCount;
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
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? GlassColors.glassDark : GlassColors.glassLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? GlassColors.separatorDark : GlassColors.separatorLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Album', style: TextStyle(color: Colors.red)),
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
      child: kIsWeb && album.thumbnailUrl != null 
          ? Image.network(album.thumbnailUrl!, fit: BoxFit.cover)
          : (album.coverAsset != null
              ? AssetEntityImage(
                  album.coverAsset!,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(400), // Larger for grid
                  fit: BoxFit.cover,
                )
              : Icon(
                  Icons.photo_library_outlined, 
                  color: isDark ? GlassColors.textTertiaryDark : GlassColors.textTertiaryLight,
                  size: 40,
                )),
    );
  }
}


