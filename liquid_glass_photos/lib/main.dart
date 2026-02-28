import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide PerformanceOverlay;
import 'package:provider/provider.dart';

import 'theme/glass_theme.dart';
import 'providers/media_index_provider.dart';
import 'providers/selection_provider.dart';
import 'providers/album_provider.dart';
import 'screens/home_screen.dart';
import 'screens/permission_screen.dart';
import 'services/app_startup_service.dart';
import 'state/scroll_state_manager.dart';

enum PhotoViewerState { idle, draggingVertical, zoomed }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Restore previous performance-oriented cache limits
  PaintingBinding.instance.imageCache.maximumSizeBytes = 300 * 1024 * 1024; // 300MB
  PaintingBinding.instance.imageCache.maximumSize = 2000; // Original high limit

  // Create provider BEFORE runApp so we can pass it via .value()
  final mediaIndexProvider = MediaIndexProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: mediaIndexProvider),
        ChangeNotifierProvider(create: (_) => SelectionProvider()),
        ChangeNotifierProvider(create: (_) => AlbumProvider()),
        Provider(create: (_) => ScrollStateManager()),
        ChangeNotifierProvider(create: (_) => ViewerState()),
      ],
      child: const LiquidGlassPhotosApp(),
    ),
  );
}

class LiquidGlassPhotosApp extends StatelessWidget {
  const LiquidGlassPhotosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Glass Photos',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.darkTheme,
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final provider = context.read<MediaIndexProvider>();
      final hasPermission = await provider.checkPermission();
      
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _isChecking = false;
        });

        // ⚡️ HEAVY WORK: Start AFTER first frame renders
        if (hasPermission) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppStartupService.instance.postFirstFrame(
              mediaProvider: context.read<MediaIndexProvider>(),
            );
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Critical: Permission check failed -> $e');
      }
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    if (kIsWeb) return;
    
    final provider = context.read<MediaIndexProvider>();
    final granted = await provider.requestPermission();
    
    if (mounted && granted) {
      setState(() {
        _hasPermission = true;
      });
      
      // ⚡️ Start heavy work AFTER permission granted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppStartupService.instance.postFirstFrame(
          mediaProvider: context.read<MediaIndexProvider>(),
        );
      });
    } else if (mounted && !granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied. Please enable access in settings.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleOpenSettings() async {
    final provider = context.read<MediaIndexProvider>();
    await provider.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    // Still checking permission - show loading
    if (_isChecking) {
      return Scaffold(
        backgroundColor: GlassColors.backgroundDark,
        body: const Center(
          child: CupertinoActivityIndicator(radius: 12),
        ),
      );
    }
    
    // Permission denied - show permission screen
    if (!_hasPermission) {
      return PermissionScreen(
        onRequestPermission: _requestPermission,
        onOpenSettings: _handleOpenSettings,
      );
    }
    
    // ⚡️ Permission granted - show HomeScreen immediately
    // Heavy work starts via postFirstFrame callback
    return const HomeScreen();
  }
}
