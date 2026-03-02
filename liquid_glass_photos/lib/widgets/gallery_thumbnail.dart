import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class GalleryThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const GalleryThumbnail({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return ExtendedImage(
      // ✅ FIX: Use Provider instead of FutureBuilder.
      // It auto-caches the thumbnail bytes, so rebuilds are instant (0ms).
      image: AssetEntityImageProvider(
        asset,
        isOriginal: false, // Fetch thumbnail
        thumbnailSize: const ThumbnailSize.square(
          200,
        ), // Higher res for modern phones
        thumbnailFormat: ThumbnailFormat.jpeg, // Faster decode
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true, // Prevents white flash during scrolling
      enableMemoryCache: true,
      clearMemoryCacheWhenDispose:
          false, // ✅ FIX: Keep cache when scrolling off-screen
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.completed:
            return state.completedWidget;
          case LoadState.failed:
            // ✅ FIX: Handle decoder failure gracefully (prevent crash)
            return const ColoredBox(
              color: Color(0xFF202020),
              child: Center(
                child: Icon(Icons.error_outline, color: Colors.grey, size: 20),
              ),
            );
          case LoadState.loading:
            return const ColoredBox(color: Color(0xFF202020));
        }
      },
    );
  }
}
