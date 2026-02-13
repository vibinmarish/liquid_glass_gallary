import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../providers/media_index_provider.dart';
import '../theme/glass_theme.dart';

/// A diagnostic overlay for performance monitoring.
/// Shows FPS, Cache health, and memory pressure alerts.
class PerformanceOverlay extends StatefulWidget {
  final Widget child;
  const PerformanceOverlay({super.key, required this.child});

  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final List<double> _frameTimes = [];
  double _fps = 0;
  
  @override
  void initState() {
    super.initState();
    _ticker = createTicker((duration) {
      _updateFps();
    });
    _ticker.start();
  }

  void _updateFps() {
    final now = WidgetsBinding.instance.currentFrameTimeStamp.inMicroseconds / 1000000.0;
    _frameTimes.add(now);
    
    // Keep only last 1 second of frame times
    while (_frameTimes.isNotEmpty && _frameTimes.first < now - 1.0) {
      _frameTimes.removeAt(0);
    }
    
    if (mounted) {
      setState(() {
        _fps = _frameTimes.length.toDouble();
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 16,
          bottom: 110, // Above nav bar
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetricRow(
                      label: 'FPS',
                      value: _fps.toStringAsFixed(0),
                      color: _fps > 55 ? Colors.greenAccent : (_fps > 30 ? Colors.orangeAccent : Colors.redAccent),
                    ),
                    const SizedBox(height: 4),
const SizedBox(height: 4),
                    const SizedBox(height: 4),
                    Consumer<MediaIndexProvider>(
                      builder: (context, p, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MetricRow(
                            label: 'ALBUM',
                            value: p.currentAlbumName,
                            color: Colors.yellowAccent,
                          ),
                          const SizedBox(height: 4),
                          _MetricRow(
                            label: 'TOTAL',
                            value: '${p.totalAssetsFound}',
                            color: Colors.cyanAccent,
                          ),
                          const SizedBox(height: 4),
                          _MetricRow(
                            label: 'ITEMS',
                            value: '${p.mediaItems.length}',
                            color: Colors.purpleAccent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
