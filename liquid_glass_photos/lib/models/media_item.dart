import 'package:photo_manager/photo_manager.dart';

/// Represents a photo or video item in the library
class MediaItem {
  final String id;
  final AssetEntity? asset; // null on web
  final bool isVideo;
  final int? duration; // milliseconds
  final String? webUrl;
  final DateTime? createDate;
  final bool isFavorite;

  MediaItem({
    required this.id,
    this.asset,
    required this.isVideo,
    this.duration,
    this.webUrl,
    this.createDate,
    this.isFavorite = false,
  });

  MediaItem copyWith({bool? isFavorite, DateTime? createDate}) {
    return MediaItem(
      id: id,
      asset: asset,
      isVideo: isVideo,
      duration: duration,
      webUrl: webUrl,
      createDate: createDate ?? this.createDate,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
