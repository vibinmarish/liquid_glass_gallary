import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

/// Represents an album containing media items
class Album {
  final String id;
  final String name;
  final int itemCount;
  final AssetPathEntity? assetPath; // Nullable for web
  final bool isSystem; // System albums like Camera Roll, Screenshots
  final String? thumbnailUrl; // For web demo
  final AssetEntity? coverAsset; // 👈 Add this line

  Album({
    required this.id,
    required this.name,
    required this.itemCount,
    this.assetPath,
    this.isSystem = false,
    this.thumbnailUrl,
    this.coverAsset, // 👈 Add this line
  });
}

class AlbumProvider extends ChangeNotifier {
  List<Album> _albums = [];
  List<Album> _systemAlbums = [];
  List<Album> _userAlbums = [];
  bool _isLoading = false;
  String? _error;

  List<Album> get albums => _albums;
  List<Album> get systemAlbums => _systemAlbums;
  List<Album> get userAlbums => _userAlbums;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Create a new album
  Future<bool> createAlbum(String name) async {
    if (kIsWeb) {
      _userAlbums.add(
        Album(
          id: 'new_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          itemCount: 0,
        ),
      );
      _albums = [..._systemAlbums, ..._userAlbums];
      notifyListeners();
      return true;
    }

    try {
      // PhotoManager 3.x uses platform-specific editors
      AssetPathEntity? path;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        path = await PhotoManager.editor.darwin.createAlbum(name);
      } else {
        // On Android, creating an empty album isn't directly supported by MediaStore
        // in the same way. Usually done by saving an asset to a path.
        _error = 'Album creation not supported on this platform';
        notifyListeners();
        return false;
      }

      if (path != null) {
        await loadAlbums();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete an album (user albums only)
  Future<bool> deleteAlbum(Album album) async {
    if (kIsWeb) {
      _userAlbums.removeWhere((a) => a.id == album.id);
      _albums = [..._systemAlbums, ..._userAlbums];
      notifyListeners();
      return true;
    }

    if (album.assetPath == null) return false;

    try {
      bool result = false;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        result = await PhotoManager.editor.darwin.deletePath(album.assetPath!);
      } else {
        _error = 'Album deletion not supported on this platform';
        notifyListeners();
        return false;
      }

      if (result) {
        await loadAlbums();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load all albums from device
  Future<void> loadAlbums() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (kIsWeb) {
      await _loadWebDemoData();
      return;
    }

    try {
      // Get all albums
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      _albums = [];
      _systemAlbums = [];
      _userAlbums = [];

      for (final path in paths) {
        final count = await path.assetCountAsync;
        final isSystem = _isSystemAlbum(path.name);

        // ✅ Change: Fetch the first image now
        final List<AssetEntity> covers = await path.getAssetListRange(
          start: 0,
          end: 1,
        );
        final AssetEntity? coverAsset = covers.isNotEmpty ? covers.first : null;

        final album = Album(
          id: path.id,
          name: path.name,
          itemCount: count,
          assetPath: path,
          isSystem: isSystem,
          coverAsset: coverAsset, // ✅ Pass it to the model
        );

        _albums.add(album);
        if (isSystem) {
          _systemAlbums.add(album);
        } else {
          _userAlbums.add(album);
        }
      }

      // Sort alphabetically first
      _systemAlbums.sort((a, b) => a.name.compareTo(b.name));
      _userAlbums.sort((a, b) => a.name.compareTo(b.name));

      // Inject synthetic Favorites album if not present (some Android devices don't have a system Favorites album)
      if (!_systemAlbums.any(
        (a) => a.id == 'favorites' || a.name.toLowerCase() == 'favorites',
      )) {
        final favAlbum = Album(
          id: 'favorites',
          name: 'Favorites',
          itemCount: 0,
          isSystem: true,
        );
        _systemAlbums.insert(0, favAlbum);
      } else {
        // Move existing favorites album to top
        final favIndex = _systemAlbums.indexWhere(
          (a) => a.id == 'favorites' || a.name.toLowerCase() == 'favorites',
        );
        if (favIndex > 0) {
          final fav = _systemAlbums.removeAt(favIndex);
          _systemAlbums.insert(0, fav);
        }
      }

      // Update main albums list with pinned favorites
      _albums = [..._systemAlbums, ..._userAlbums];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isSystemAlbum(String name) {
    final systemNames = [
      'All',
      'Recent',
      'Camera',
      'Screenshots',
      'Videos',
      'Download',
      'DCIM',
      'Pictures',
      'Movies',
      'Recents',
      'Camera Roll',
      'All Photos',
      'All Videos',
    ];
    return systemNames.any((s) => name.toLowerCase().contains(s.toLowerCase()));
  }

  /// Load demo data for web
  Future<void> _loadWebDemoData() async {
    await Future.delayed(const Duration(milliseconds: 300));

    _systemAlbums = [
      Album(
        id: 'all',
        name: 'All Photos',
        itemCount: 234,
        isSystem: true,
        thumbnailUrl: 'https://picsum.photos/seed/all/200/200',
      ),
      Album(
        id: 'camera',
        name: 'Camera',
        itemCount: 156,
        isSystem: true,
        thumbnailUrl: 'https://picsum.photos/seed/camera/200/200',
      ),
      Album(
        id: 'screenshots',
        name: 'Screenshots',
        itemCount: 42,
        isSystem: true,
        thumbnailUrl: 'https://picsum.photos/seed/screenshots/200/200',
      ),
      Album(
        id: 'videos',
        name: 'Videos',
        itemCount: 18,
        isSystem: true,
        thumbnailUrl: 'https://picsum.photos/seed/videos/200/200',
      ),
    ];

    _userAlbums = [
      Album(
        id: 'vacation',
        name: 'Vacation 2025',
        itemCount: 89,
        thumbnailUrl: 'https://picsum.photos/seed/vacation/200/200',
      ),
      Album(
        id: 'family',
        name: 'Family',
        itemCount: 67,
        thumbnailUrl: 'https://picsum.photos/seed/family/200/200',
      ),
      Album(
        id: 'work',
        name: 'Work',
        itemCount: 23,
        thumbnailUrl: 'https://picsum.photos/seed/work/200/200',
      ),
    ];

    _albums = [..._systemAlbums, ..._userAlbums];
    _isLoading = false;
    notifyListeners();
  }
}
