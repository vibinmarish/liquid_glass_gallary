import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../theme/glass_settings.dart';

import '../models/media_item.dart';
import '../providers/ui_provider.dart';
import '../providers/media_index_provider.dart';
import '../providers/album_provider.dart';

class ContextMenuOverlay extends StatelessWidget {
  final MediaItem item;
  final Offset position;
  final Size screenSize;

  const ContextMenuOverlay({
    super.key,
    required this.item,
    required this.position,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    const menuWidth = 280.0;
    const menuHeight = 200.0;

    // Calculate best position
    double left = position.dx - menuWidth / 2;
    double top = position.dy - menuHeight - 20; // Prefer above with 20px gap

    // Check horizontal bounds
    if (left < 16) left = 16;
    if (left + menuWidth > screenSize.width - 16) {
      left = screenSize.width - menuWidth - 16;
    }

    // Check vertical bounds - if not enough space above, try below
    if (top < 60) {
      top = position.dy + 20; // Below the tap point
    }
    // If still not enough space below, center vertically
    if (top + menuHeight > screenSize.height - 100) {
      top = (screenSize.height - menuHeight) / 2;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        type: MaterialType.transparency,
        child: GlassContainer(
          useOwnLayer: true,
          width: menuWidth,
          settings: AppGlassSettings.menu,
          quality: GlassQuality.premium,
          shape: const LiquidRoundedSuperellipse(borderRadius: 24),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassMenuItem(
                  title: 'Share',
                  icon: Icons.ios_share_rounded,
                  onTap: () async {
                    context.read<UIProvider>().hideContextMenu();
                    final file = await item.asset?.file;
                    if (file != null) {
                      await Share.shareXFiles([XFile(file.path)]);
                    }
                  },
                ),
                GlassMenuItem(
                  title: 'Add to Album',
                  icon: Icons.add_photo_alternate_outlined,
                  onTap: () {
                    context.read<UIProvider>().hideContextMenu();
                    context.read<UIProvider>().setShowNewAlbumDialog(true);
                  },
                ),
                GlassMenuItem(
                  title: 'Favorite',
                  icon:
                      item.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                  onTap: () {
                    context.read<UIProvider>().hideContextMenu();
                    context.read<MediaIndexProvider>().toggleFavorite(item);
                    HapticFeedback.mediumImpact();
                  },
                ),
                GlassMenuItem(
                  title: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  isDestructive: true,
                  onTap: () {
                    context.read<UIProvider>().showDeleteConfirm(item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteConfirmOverlay extends StatelessWidget {
  final MediaItem item;

  const DeleteConfirmOverlay({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GlassDialog(
        title: 'Delete Photo?',
        message: 'This photo will be moved to the trash.',
        maxWidth: 280,
        settings: AppGlassSettings.dialog,
        actions: [
          GlassDialogAction(
            label: 'Cancel',
            onPressed: () => context.read<UIProvider>().hideDeleteConfirm(),
          ),
          GlassDialogAction(
            label: 'Delete',
            isDestructive: true,
            onPressed: () async {
              final ui = context.read<UIProvider>();
              ui.hideDeleteConfirm();
              await context.read<MediaIndexProvider>().deleteMediaItems({
                item.id,
              });
            },
          ),
        ],
      ),
    );
  }
}

class NewAlbumDialogOverlay extends StatefulWidget {
  const NewAlbumDialogOverlay({super.key});

  @override
  State<NewAlbumDialogOverlay> createState() => _NewAlbumDialogOverlayState();
}

class _NewAlbumDialogOverlayState extends State<NewAlbumDialogOverlay> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GlassContainer(
        width: 300,
        height: 200,
        settings: AppGlassSettings.dialog.copyWith(
          blur: 20,
        ),
        shape: const LiquidRoundedRectangle(borderRadius: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'New Album',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _controller,
                autofocus: true,
                placeholder: 'Album Name',
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        () => context.read<UIProvider>().setShowNewAlbumDialog(
                          false,
                        ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      if (_controller.text.isNotEmpty) {
                        final success = await context
                            .read<AlbumProvider>()
                            .createAlbum(_controller.text);
                        if (success && mounted) {
                          context.read<UIProvider>().setShowNewAlbumDialog(
                            false,
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
