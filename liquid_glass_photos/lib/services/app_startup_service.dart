import 'dart:async';
import '../providers/media_index_provider.dart';

/// ⚡️ iOS-STYLE STARTUP: Minimal blocking before runApp, heavy work after first frame
class AppStartupService {
  static final instance = AppStartupService._();
  AppStartupService._();

  bool _started = false;

  /// ⚡️ HEAVY – must run AFTER first frame renders
  /// Called from HomeScreen/LibraryScreen initState via addPostFrameCallback
  void postFirstFrame({required MediaIndexProvider mediaProvider}) {
    if (_started) return;
    _started = true;

    // Fire-and-forget (don't await, let UI stay responsive)
    unawaited(mediaProvider.initialize());
  }
}
