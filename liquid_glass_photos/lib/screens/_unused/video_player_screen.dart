import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import '../models/media_item.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_button.dart';

/// iOS 26 Video Player Screen with Liquid Glass Controls
class VideoPlayerScreen extends StatefulWidget {
  final MediaItem mediaItem;
  
  const VideoPlayerScreen({super.key, required this.mediaItem});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _startControlsTimer();
  }
  
  Future<void> _initializePlayer() async {
    if (kIsWeb) {
      setState(() => _isInitialized = false);
      return;
    }
    
    if (widget.mediaItem.asset == null) return;
    
    final file = await widget.mediaItem.asset!.file;
    if (file == null || !mounted) return;
    
    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
    await _controller!.play();
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
    
    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
  }
  
  void _startControlsTimer() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _showControls && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  
  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }
  
  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
      _startControlsTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black, // Video background always black
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Layer
            Center(
              child: _isInitialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : _WebVideoPlaceholder(),
            ),
            
            // Top Bar Overlay (Liquid Glass)
            if (_showControls)
              LiquidGlass(
                width: screenSize.width - 32,
                height: 56,
                magnification: 1.0,
                distortion: 0.05,
                distortionWidth: 20,
                position: LiquidGlassAlignPosition(
                  alignment: Alignment.topCenter,
                  margin: EdgeInsets.only(top: topPadding + 8),
                ),
                blur: const LiquidGlassBlur(sigmaX: 25, sigmaY: 25),
                color: isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(15),
                shape: RoundedRectangleShape(cornerRadius: 28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black, size: 20),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Video',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for back button
                    ],
                  ),
                ),
              ),

            // Bottom Player Controls (Liquid Glass)
            if (_showControls && _isInitialized)
              LiquidGlass(
                width: screenSize.width - 32,
                height: 100,
                magnification: 1.0,
                distortion: 0.05,
                distortionWidth: 20,
                position: LiquidGlassAlignPosition(
                  alignment: Alignment.bottomCenter,
                  margin: EdgeInsets.only(bottom: bottomPadding + 16),
                ),
                blur: const LiquidGlassBlur(sigmaX: 30, sigmaY: 30),
                color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
                shape: RoundedRectangleShape(cornerRadius: 32),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VideoProgressBar(controller: _controller!),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => _controller!.seekTo(_controller!.value.position - const Duration(seconds: 10)),
                            icon: Icon(Icons.replay_10, color: isDark ? Colors.white : Colors.black),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: isDark ? Colors.white : Colors.black,
                              size: 40,
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            onPressed: () => _controller!.seekTo(_controller!.value.position + const Duration(seconds: 10)),
                            icon: Icon(Icons.forward_10, color: isDark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoProgressBar extends StatelessWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final progress = duration.inMilliseconds > 0 ? position.inMilliseconds / duration.inMilliseconds : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? Colors.white : Colors.black;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position), style: TextStyle(color: onSurface, fontSize: 10)),
            Text(
              '-${_formatDuration(duration - position)}', 
              style: TextStyle(color: onSurface.withOpacity(0.7), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 4,
              width: double.infinity,
              decoration: BoxDecoration(color: onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(color: GlassColors.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _WebVideoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videocam_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 16),
        const Text(
          'Video Demo\n(Mobile Required for Assets)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    );
  }
}
