import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

/// Handles media indexing, metadata, and permissions.
class MediaIndexProvider extends ChangeNotifier {
  // paging state
  static const int _pageSize = 500;
  int _currentPage = 0;
  bool _hasMore = true;
  AssetPathEntity? _currentAlbum;

  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String? _error;
  final Set<String> _deletedIds = {};
  int? _cachedCount;

  String _currentAlbumName = 'None';
  int _totalAssetsFound = 0;

  // ✅ FIX: Surgical Cache for Viewer
  List<AssetEntity> _cachedAssets = [];
  List<AssetEntity> get cachedAssets => _cachedAssets;

  void _updateCache() {
    _cachedAssets =
        _mediaItems.map((m) => m.asset).whereType<AssetEntity>().toList();
  }

  List<MediaItem> get mediaItems => _mediaItems;
  List<MediaItem> get favoriteItems =>
      _mediaItems.where((item) => item.isFavorite).toList();
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isFetching => _isFetching;
  String? get error => _error;
  String get currentAlbumName => _currentAlbumName;
  int get totalAssetsFound => _totalAssetsFound;

  int get displayCount =>
      _mediaItems.length <= 100 && _cachedCount != null && _cachedCount! > 100
          ? _cachedCount!
          : _mediaItems.length;

  bool get hasKnownPhotos =>
      _mediaItems.isNotEmpty || (_cachedCount != null && _cachedCount! > 0);

  // ⚡️ STARTUP: Safe count accessor to prevent jumps (0 → 100 → 2462)
  int get safePhotoCount {
    if (_cachedCount != null && _cachedCount! > 0) {
      if (_mediaItems.length < _cachedCount!) {
        return _cachedCount!;
      }
    }
    if (_mediaItems.isNotEmpty) {
      return _mediaItems.length;
    }
    return _cachedCount ?? 0;
  }

  /// ⚡️ PRE-RUNAPP: Load cached count BEFORE first frame
  Future<void> loadCachedCountOnly() async {
    await _loadCachedCount();
  }

  // ⚡️ GUARDS: Prevent double initialization
  bool _isInitializing = false;
  bool _initialized = false;

  /// ⚡️ POST-FIRST-FRAME: Heavy work happens here
  Future<void> initialize() async {
    if (_isInitializing || _initialized) return;
    _isInitializing = true;

    try {
      await _loadCachedCount();
      notifyListeners();

      PhotoManager.addChangeCallback(_onMediaChanged);
      PhotoManager.setIgnorePermissionCheck(true);

      await loadMedia();
    } finally {
      _isInitializing = false;
      _initialized = true;
    }
  }

  /// Initial load (reset and load page 0)
  Future<void> loadMedia({bool showLoadingIndicator = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (_mediaItems.isEmpty || showLoadingIndicator) {
      _isLoading = true;
      notifyListeners();
      if (showLoadingIndicator) {
        _mediaItems = [];
        _currentPage = 0;
        _hasMore = true;
        _currentAlbum = null;
      }
    }
    _error = null;

    if (kIsWeb) {
      _finishLoading();
      return;
    }

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (permission.isAuth == false && permission != PermissionState.limited) {
        _error = 'Permission denied. Please enable access in settings.';
        _finishLoading();
        return;
      }

      // Find best album if not set
      if (_currentAlbum == null) {
        final filterOption = FilterOptionGroup(
          orders: const [
            OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        );

        // Only load Recent album first for speed
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          filterOption: filterOption,
          hasAll: true,
          onlyAll: true,
        );

        if (albums.isEmpty) {
          _mediaItems = [];
          _currentAlbumName = 'None';
          _finishLoading();
          return;
        }
        _currentAlbum = albums.first;
      }

      _currentAlbumName = _currentAlbum!.name;
      _totalAssetsFound = await _currentAlbum!.assetCountAsync;

      // Load first page
      // Load first page
      final batch = await _fetchNextBatch(0);

      _mediaItems = batch.items;
      _currentPage = batch.lastPage;
      _hasMore = batch.hasMore;

      if (_mediaItems.isNotEmpty) {
        _saveCountToCache();
      }
    } finally {
      _finishLoading();
    }
  }

  Future<void> refresh() async {
    await loadMedia(showLoadingIndicator: false);
  }

  Future<void> loadMore() async {
    if (_isFetching || !_hasMore || _currentAlbum == null) {
      return;
    }
    _isFetching = true;
    notifyListeners(); // ⚡️ Notify start to show loading state

    try {
      final batch = await _fetchNextBatch(_currentPage + 1);

      if (batch.items.isNotEmpty) {
        _mediaItems.addAll(batch.items);
        _currentPage = batch.lastPage;
        _hasMore = batch.hasMore;
        _updateCache();
      } else {
        _hasMore = false;
      }
    } finally {
      _isFetching = false;
      notifyListeners(); // ⚡️ Notify end to trigger UI update (and potential next fetch)
    }
  }

  /// Robustly fetch next batch, skipping empty/filtered pages
  Future<({List<MediaItem> items, int lastPage, bool hasMore})> _fetchNextBatch(
    int startPage,
  ) async {
    if (_currentAlbum == null) {
      return (items: <MediaItem>[], lastPage: startPage, hasMore: false);
    }

    int currentPage = startPage;
    List<MediaItem> collectedItems = [];
    bool hasMore = true;

    // Safety: Don't loop forever if entire album is deleted items
    int loops = 0;
    const maxLoops = 20;

    while (collectedItems.isEmpty && hasMore && loops < maxLoops) {
      final rawAssets = await _currentAlbum!.getAssetListPaged(
        page: currentPage,
        size: _pageSize,
      );

      if (rawAssets.isEmpty) {
        hasMore = false;
        break;
      }

      final validItems =
          rawAssets
              .where((asset) => !_deletedIds.contains(asset.id))
              // Filter out broken files
              .where((asset) => asset.width > 0 && asset.height > 0)
              .map((asset) => _mapAssetToItem(asset))
              .toList();

      if (validItems.isNotEmpty) {
        collectedItems.addAll(validItems);
      } else {
        // Page was full of junk/deleted items, try next page
        currentPage++;
      }

      if (rawAssets.length < _pageSize) {
        hasMore = false;
      }

      loops++;
    }

    return (
      items: collectedItems,
      lastPage: currentPage,
      hasMore: hasMore && collectedItems.isNotEmpty,
    );
  }

  void _finishLoading() {
    _isLoading = false;
    _isFetching = false;
    _updateCache(); // ✅ Update cache before notify
    notifyListeners();
  }

  Future<void> _loadCachedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedCount = prefs.getInt('media_count_cache');
      if (_cachedCount != null && _cachedCount! > 0) {
        notifyListeners();
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _saveCountToCache() async {
    if (_mediaItems.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('media_count_cache', _totalAssetsFound);
    } catch (e) {
      // Ignored
    }
  }

  MediaItem _mapAssetToItem(AssetEntity asset) {
    return MediaItem(
      id: asset.id,
      asset: asset,
      isVideo: asset.type == AssetType.video,
      duration: asset.type == AssetType.video ? asset.duration * 1000 : null,
      createDate: asset.createDateTime,
      isFavorite: asset.isFavorite,
    );
  }

  Future<void> deleteMediaItems(Set<String> ids) async {
    if (ids.isEmpty) return;

    final List<String> assetIds = [];
    for (final id in ids) {
      final item = _mediaItems.cast<MediaItem?>().firstWhere(
        (i) => i?.id == id,
        orElse: () => null,
      );
      if (item?.asset?.id != null) assetIds.add(item!.asset!.id);
    }

    if (assetIds.isNotEmpty) {
      try {
        // ✅ FIX: Capture actual result from OS prompt
        final List<String> result = await PhotoManager.editor.deleteWithIds(
          assetIds,
        );

        // ✅ FIX: Only remove items actually deleted
        if (result.isNotEmpty) {
          _mediaItems.removeWhere((item) => result.contains(item.asset?.id));
          _deletedIds.addAll(
            result,
          ); // Track deleted IDs to filter subsequent pages
          _updateCache();
          notifyListeners();
        }
      } catch (e) {
        // Ignored
      }
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (item.asset != null) {
      final newState = !item.isFavorite;
      try {
        bool success = false;
        if (Platform.isIOS || Platform.isMacOS) {
          await PhotoManager.editor.darwin.favoriteAsset(
            entity: item.asset!,
            favorite: newState,
          );
          success = true;
        } else {
          success = true;
        }

        if (success) {
          final index = _mediaItems.indexWhere((i) => i.id == item.id);
          if (index != -1) {
            _mediaItems[index] = item.copyWith(isFavorite: newState);
            notifyListeners();
          }
        }
      } catch (e) {
        // Ignored
      }
    }
  }

  void _onMediaChanged(MethodCall call) async {
    // Debounce slightly
    await Future.delayed(const Duration(milliseconds: 1000));
    // Reload reset
    await loadMedia(showLoadingIndicator: false);
  }

  Future<bool> checkPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state == PermissionState.limited;
  }

  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state == PermissionState.limited;
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  // -------------------------
  // Grouping (Month / Year)
  // -------------------------

  Map<String, List<MediaItem>> get groupedMedia {
    final Map<String, List<MediaItem>> grouped = {};

    if (kIsWeb) {
      // Mock data for web
      return {};
    }

    for (final item in _mediaItems) {
      final date = item.createDate;
      if (date == null) continue;

      final key = '${_monthName(date.month)} ${date.year}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    final sortedKeys =
        grouped.keys.toList()..sort((a, b) {
          final aParts = a.split(' ');
          final bParts = b.split(' ');
          final aMonth = _monthNumber(aParts[0]);
          final bMonth = _monthNumber(bParts[0]);
          final aYear = int.parse(aParts[1]);
          final bYear = int.parse(bParts[1]);

          if (aYear != bYear) return bYear - aYear;
          return bMonth - aMonth;
        });

    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  int _monthNumber(String month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months.indexOf(month) + 1;
  }

  @override
  void dispose() {
    PhotoManager.removeChangeCallback(_onMediaChanged);
    super.dispose();
  }
}
