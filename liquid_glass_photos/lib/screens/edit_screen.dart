import 'dart:io';

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:path_provider/path_provider.dart'; // For temp file
import 'package:photo_manager/photo_manager.dart'; // For saving to gallery
import 'package:image_editor/image_editor.dart';

import '../models/media_item.dart';
import '../theme/glass_theme.dart';
import '../theme/glass_settings.dart';

enum AdjustTool {
  exposure,
  brilliance,
  highlights,
  shadows,
  contrast,
  brightness,
  blackPoint,
  saturation,
  vibrance,
  warmth,
  tint,
  sharpness,
  definition,
  noiseReduction,
  vignette;

  String get name {
    switch (this) {
      case AdjustTool.exposure:
        return 'Exposure';
      case AdjustTool.brilliance:
        return 'Brilliance';
      case AdjustTool.highlights:
        return 'Highlights';
      case AdjustTool.shadows:
        return 'Shadows';
      case AdjustTool.contrast:
        return 'Contrast';
      case AdjustTool.brightness:
        return 'Brightness';
      case AdjustTool.blackPoint:
        return 'Black Point';
      case AdjustTool.saturation:
        return 'Saturation';
      case AdjustTool.vibrance:
        return 'Vibrance';
      case AdjustTool.warmth:
        return 'Warmth';
      case AdjustTool.tint:
        return 'Tint';
      case AdjustTool.sharpness:
        return 'Sharpness';
      case AdjustTool.definition:
        return 'Definition';
      case AdjustTool.noiseReduction:
        return 'Noise Reduction';
      case AdjustTool.vignette:
        return 'Vignette';
    }
  }

  IconData get icon {
    switch (this) {
      case AdjustTool.exposure:
        return Icons.exposure;
      case AdjustTool.brilliance:
        return Icons.flare;
      case AdjustTool.highlights:
        return Icons.highlight;
      case AdjustTool.shadows:
        return Icons.nights_stay;
      case AdjustTool.contrast:
        return Icons.contrast;
      case AdjustTool.brightness:
        return Icons.brightness_6;
      case AdjustTool.blackPoint:
        return Icons.point_of_sale; // Placeholder
      case AdjustTool.saturation:
        return Icons.stream; // Placeholder
      case AdjustTool.vibrance:
        return Icons.blur_on;
      case AdjustTool.warmth:
        return Icons.thermostat;
      case AdjustTool.tint:
        return Icons.color_lens;
      case AdjustTool.sharpness:
        return Icons.details;
      case AdjustTool.definition:
        return Icons.high_quality;
      case AdjustTool.noiseReduction:
        return Icons.graphic_eq;
      case AdjustTool.vignette:
        return Icons.vignette;
    }
  }
}

class EditScreen extends StatefulWidget {
  final MediaItem mediaItem;

  const EditScreen({super.key, required this.mediaItem});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  File? _file;
  bool _isSaving = false;

  // Base values from filters
  double _baseBrightness = 0.0;
  double _baseContrast = 1.0;
  double _baseSaturation = 1.0;
  double _baseWarmth = 0.0;

  // User offsets from sliders
  final Map<AdjustTool, double> _adjustmentValues = {
    for (var tool in AdjustTool.values) tool: 0.0,
  };

  // Interaction state

  // Crop & Transform state
  // Crop & Transform state
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
  double _straightenAngle = 0.0; // Radians
  int _quarterTurns = 0;
  bool _isFlipped = false;
  double _aspectRatio = -1;
  double _scale = 1.0;
  Offset _pan = Offset.zero;

  int _selectedCategory = 0; // 0: Styles, 1: Adjust, 2: Crop
  AdjustTool _selectedAdjustTool = AdjustTool.exposure;
  String? _selectedFilter = 'Original';

  final List<Map<String, dynamic>> _styleFilters = [
    {
      'name': 'Original',
      'matrix': [0.0, 1.0, 1.0, 0.0],
    },
    {
      'name': 'Vivid',
      'matrix': [0.1, 1.2, 1.3, 0.0],
    },
    {
      'name': 'Warm',
      'matrix': [0.05, 1.0, 1.0, 0.3],
    },
    {
      'name': 'Cool',
      'matrix': [0.0, 1.0, 0.9, -0.3],
    },
    {
      'name': 'B&W',
      'matrix': [0.0, 1.1, 0.0, 0.0],
    },
    {
      'name': 'Vintage',
      'matrix': [0.0, 0.9, 0.7, 0.2],
    },
    {
      'name': 'Dramatic',
      'matrix': [-0.1, 1.4, 0.8, 0.0],
    },
    {
      'name': 'Fade',
      'matrix': [0.1, 0.8, 0.85, 0.0],
    },
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.mediaItem.asset != null) {
      _loadFile();
    }
  }

  double? _imageWidth;
  double? _imageHeight;

  Future<void> _loadFile() async {
    final file = await widget.mediaItem.asset?.file;
    if (mounted && file != null) {
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      setState(() {
        _file = file;
        _imageWidth = decoded.width.toDouble();
        _imageHeight = decoded.height.toDouble();
      });
    }
  }
  // ... (keeping existing methods)

  void _applyFilter(String name) {
    final filter = _styleFilters.firstWhere((f) => f['name'] == name);
    final values = filter['matrix'] as List<double>;
    setState(() {
      _selectedFilter = name;
      _baseBrightness = values[0];
      _baseContrast = values[1];
      _baseSaturation = values[2];
      _baseWarmth = values[3];
    });
    HapticFeedback.selectionClick();
  }

  double _autoScaleForRotation(double angle) {
    return 1.0 / (math.cos(angle.abs()));
  }

  Rect _applyAspectRatio(Rect r, double ratio) {
    if (ratio <= 0) return r;

    final center = r.center;
    double w = r.width;
    double h = w / ratio;

    if (h > r.height) {
      h = r.height;
      w = h * ratio;
    }

    return Rect.fromCenter(center: center, width: w, height: h);
  }

  void _resetCrop() {
    setState(() {
      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
      _straightenAngle = 0.0;
      _quarterTurns = 0;
      _isFlipped = false;
      _scale = 1.0;
      _pan = Offset.zero;
      _aspectRatio = -1;
    });
  }

  List<double> _saturationMatrix(double s) {
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;

    return [
      lumR * (1 - s) + s,
      lumG * (1 - s),
      lumB * (1 - s),
      0,
      0,
      lumR * (1 - s),
      lumG * (1 - s) + s,
      lumB * (1 - s),
      0,
      0,
      lumR * (1 - s),
      lumG * (1 - s),
      lumB * (1 - s) + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _multiplyMatrices(List<double> m1, List<double> m2) {
    final result = List<double>.filled(20, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += m1[i * 5 + k] * m2[k * 5 + j];
        }
        result[i * 5 + j] = sum;
      }
      double tSum = 0;
      for (int k = 0; k < 4; k++) {
        tSum += m1[i * 5 + k] * m2[k * 5 + 4];
      }
      result[i * 5 + 4] = tSum + m1[i * 5 + 4];
    }
    return result;
  }

  List<double> _tintMatrix(double t) {
    // Rotate RGB around the Green-Magenta axis
    // Simplified approximation:
    // +t (Magenta) -> Boost R & B, Limit G
    // -t (Green) -> Boost G, Limit R & B

    // R G B A W
    return [
      1.0 + t * 0.5,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0 - t * 0.5,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0 + t * 0.5,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  List<double> _calculateColorMatrix() {
    // Additive logic: Filters set base, Sliders apply offsets

    // 1. Exposure / Brightness / Brilliance / Highlights / Shadows
    double exposure = _adjustmentValues[AdjustTool.exposure] ?? 0;
    double brightness = _adjustmentValues[AdjustTool.brightness] ?? 0;
    double brilliance = _adjustmentValues[AdjustTool.brilliance] ?? 0;
    double highlights = _adjustmentValues[AdjustTool.highlights] ?? 0;
    double shadows = _adjustmentValues[AdjustTool.shadows] ?? 0;

    // Brilliance affects both brightness and contrast
    // Highlights simply pulls down brightness for now (approx)
    // Shadows boosts brightness for now (approx)

    double b =
        _baseBrightness +
        exposure +
        (brightness * 0.6) +
        (brilliance * 0.4) -
        (highlights * 0.3) // Highlights recovery -> darken
        +
        (shadows * 0.3); // Shadows boost -> lighten

    // 2. Contrast / Black Point
    double contrast = _adjustmentValues[AdjustTool.contrast] ?? 0;
    double blackPoint = _adjustmentValues[AdjustTool.blackPoint] ?? 0;

    // Proxies for Detail tools
    double sharpness = _adjustmentValues[AdjustTool.sharpness] ?? 0;
    double definition = _adjustmentValues[AdjustTool.definition] ?? 0;
    double noiseReduction = _adjustmentValues[AdjustTool.noiseReduction] ?? 0;

    // Sharpness/Definition boost contrast slightly to simulate pop
    // Noise reduction reduces contrast slightly

    double c =
        _baseContrast *
        (1.0 +
            contrast +
            (brilliance * 0.2) +
            (blackPoint * 0.5) +
            (sharpness * 0.1) +
            (definition * 0.1) -
            (noiseReduction * 0.1));

    // 3. Saturation / Vibrance
    double saturation = _adjustmentValues[AdjustTool.saturation] ?? 0;
    double vibrance = _adjustmentValues[AdjustTool.vibrance] ?? 0;

    double s = _baseSaturation * (1.0 + saturation + (vibrance * 0.5));

    // 4. Color: Warmth / Tint
    double warmth = _adjustmentValues[AdjustTool.warmth] ?? 0;
    double tint = _adjustmentValues[AdjustTool.tint] ?? 0;

    double w = _baseWarmth + warmth;

    // Base Matrix (Contrast + Brightness + Warmth)
    final List<double> base = [
      c,
      0.0,
      0.0,
      0.0,
      b * 100 + w * 20,
      0.0,
      c,
      0.0,
      0.0,
      b * 100,
      0.0,
      0.0,
      c,
      0.0,
      b * 100 - w * 20,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // Saturation Matrix
    final satMatrix = _saturationMatrix(s);

    // Tint Matrix
    final tintM = _tintMatrix(tint);

    // Compose: Base * Saturation * Tint
    final m1 = _multiplyMatrices(base, satMatrix);
    return _multiplyMatrices(m1, tintM);
  }

  ColorFilter _buildColorFilter() {
    return ColorFilter.matrix(_calculateColorMatrix());
  }

  Widget _buildImage() {
    if (kIsWeb && widget.mediaItem.webUrl != null) {
      return Image.network(
        widget.mediaItem.webUrl!.replaceAll('/400/400', '/600/600'),
        fit: BoxFit.contain,
      );
    } else if (_file != null) {
      return Image.file(_file!, fit: BoxFit.contain);
    } else {
      return const Center(
        child: CircularProgressIndicator(color: GlassColors.primary),
      );
    }
  }

  // Save Logic
  Future<void> _saveImage() async {
    if (_isSaving || _file == null) return;
    setState(() => _isSaving = true);

    // Show your glass loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (c) => const Center(
            child: CircularProgressIndicator(color: GlassColors.primary),
          ),
    );

    try {
      // 1. Configure Native Editor Options
      final ImageEditorOption option = ImageEditorOption();

      // A. Apply Crop
      // Calculate normalized crop to pixel coordinates
      // We use the original image dimensions (_imageWidth/Height)
      if (_cropRect != const Rect.fromLTWH(0, 0, 1, 1) && _imageWidth != null) {
        option.addOption(
          ClipOption(
            x: (_cropRect.left * _imageWidth!).round(),
            y: (_cropRect.top * _imageHeight!).round(),
            width: (_cropRect.width * _imageWidth!).round(),
            height: (_cropRect.height * _imageHeight!).round(),
          ),
        );
      }

      // B. Apply Rotation & Flip
      // Note: Native rotation is usually clockwise
      if (_quarterTurns != 0 || _straightenAngle != 0) {
        // Combine discrete 90-degree turns with fine rotation
        final degrees =
            (_quarterTurns * 90) + (_straightenAngle * 180 / math.pi);
        if (degrees != 0) option.addOption(RotateOption(degrees.round()));
      }

      if (_isFlipped) {
        option.addOption(const FlipOption(horizontal: true));
      }

      // C. Apply Color Matrix (The Liquid Glass Magic)
      // We pass the exact same matrix your UI is using
      final matrix = _calculateColorMatrix();
      option.addOption(ColorOption(matrix: matrix));

      // 2. Process File Natively (Instant)
      final Uint8List? result = await ImageEditor.editFileImage(
        file: _file!,
        imageEditorOption: option,
      );

      if (result == null) throw Exception("Native processing failed");

      // 3. Save to Temp File
      final tempDir = await getTemporaryDirectory();
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(result);

      // 4. Save to Gallery via PhotoManager (Your existing robust logic)
      await PhotoManager.editor.saveImageWithPath(
        tempFile.path,
        title: fileName,
      );

      if (mounted) {
        Navigator.pop(context); // Close loader
        Navigator.pop(context, true); // Return success to viewer

        // Optional: Clean up temp file
        try {
          tempFile.delete();
        } catch (_) {}
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Saved to Photos")));
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const bottomPanelHeight = 280.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LiquidGlassScope.stack(
        background: Stack(
            children: [
              // 1. Main Image Area
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Determine visual rect of the image
                    // We have fixed padding in the UI: Top 80, Bottom (panel height + padding)
                    // Adjust padding to account for floating tabs if necessary, but 240 is plenty.
                    final availableWidth = constraints.maxWidth;
                    final availableHeight =
                        constraints.maxHeight -
                        80 -
                        (bottomPanelHeight + bottomPadding);
  
                    Size displaySize = Size(availableWidth, availableHeight);
  
                    if (_imageWidth != null && _imageHeight != null) {
                      final fitted = applyBoxFit(
                        BoxFit.contain,
                        Size(_imageWidth!, _imageHeight!),
                        Size(availableWidth, availableHeight),
                      );
                      displaySize = fitted.destination;
                    }
  
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Centered Image + Crop Grid Area
                        Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: 80,
                              bottom: (bottomPanelHeight + bottomPadding),
                            ),
                            child: SizedBox(
                              width: displaySize.width,
                              height: displaySize.height,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                // Main Image
                                Positioned.fill(
                                  child: Center(
                                    child: ClipRect(
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform:
                                            Matrix4.identity()
                                              ..multiply(
                                                Matrix4.translationValues(
                                                  _pan.dx,
                                                  _pan.dy,
                                                  0.0,
                                                ),
                                              )
                                              ..multiply(
                                                Matrix4.diagonal3Values(
                                                  _scale *
                                                      _autoScaleForRotation(
                                                        _straightenAngle,
                                                      ),
                                                  _scale *
                                                      _autoScaleForRotation(
                                                        _straightenAngle,
                                                      ),
                                                  1.0,
                                                ),
                                              )
                                              ..rotateZ(_straightenAngle)
                                              ..rotateZ(
                                                _quarterTurns * math.pi / 2,
                                              )
                                              ..multiply(
                                                Matrix4.diagonal3Values(
                                                  _isFlipped ? -1.0 : 1.0,
                                                  1.0,
                                                  1.0,
                                                ),
                                              ),
                                        child: ColorFiltered(
                                          colorFilter: _buildColorFilter(),
                                          child: _buildImage(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Crop Overlay (Grid)
                                if (_selectedCategory == 2)
                                  Positioned.fill(
                                    child: _CropOverlay(
                                      rect: _cropRect,
                                      onRectChanged:
                                          (r) => setState(() => _cropRect = r),
                                    ),
                                  ),

                                // Vignette Overlay (Visual only, below crop grid)
                                Positioned.fill(
                                  child: _VignetteOverlay(
                                    intensity:
                                        _adjustmentValues[AdjustTool
                                            .vignette] ??
                                        0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // 2. Top Bar (Gradient Overlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _EditTopBar(
                onCancel: () => Navigator.pop(context),
                onSave: _saveImage,
                isSaving: _isSaving,
              ),
            ),

            // 3. Bottom Glass Panel (Tools Only - Native Native)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomPanelHeight + bottomPadding,
              child: _buildNativeGlassPanel(bottomPadding),
            ),
          ],
        ),
        // 4. Floating Tab Bar (Liquid Glass)
        content: AdaptiveLiquidGlassLayer(
          quality: GlassQuality.premium,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding + 16),
                  child: GlassContainer(
                    width: 280,
                    height: 60,
                    shape: const LiquidRoundedRectangle(
                      borderRadius: 32,
                    ), // Match Library Screen (32)
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TabItem(
                          icon: Icons.auto_awesome,
                          label: 'Filters',
                          isSelected: _selectedCategory == 0,
                          onTap: () => setState(() => _selectedCategory = 0),
                        ),
                        _TabItem(
                          icon: Icons.tune,
                          label: 'Adjust',
                          isSelected: _selectedCategory == 1,
                          onTap: () => setState(() => _selectedCategory = 1),
                        ),
                        _TabItem(
                          icon: Icons.crop_rotate,
                          label: 'Crop',
                          isSelected: _selectedCategory == 2,
                          onTap: () => setState(() => _selectedCategory = 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNativeGlassPanel(double bottomPadding) {
    return GlassPanel(
      settings: AppGlassSettings.bottomBar,
      useOwnLayer: true,
      quality: GlassQuality.premium,
      shape: const LiquidRoundedRectangle(borderRadius: 0),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomPadding + 80,
        ), // Clear floating tabs
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Tool Area
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildActiveToolArea(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveToolArea() {
    switch (_selectedCategory) {
      case 0:
        return _StyleCarousel(
          filters: _styleFilters,
          selectedFilter: _selectedFilter,
          onFilterSelected: _applyFilter,
          imageFile: _file,
          mediaItem: widget.mediaItem,
        );
      case 1:
        return _AdjustPanel(
          selectedTool: _selectedAdjustTool,
          onToolSelected: (tool) => setState(() => _selectedAdjustTool = tool),
          value: _adjustmentValues[_selectedAdjustTool] ?? 0.0,
          onValueChanged:
              (v) => setState(() => _adjustmentValues[_selectedAdjustTool] = v),
        );
      case 2:
        return _CropPanel(
          straightenAngle: _straightenAngle,
          onStraightenChanged: (v) => setState(() => _straightenAngle = v),
          onRotate:
              () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
          onFlip: () => setState(() => _isFlipped = !_isFlipped),
          onRatio: () {
            // Rotate ratios: Original -> Free -> Square -> 16:9
            setState(() {
              if (_aspectRatio == -1) {
                _aspectRatio = 0;
              } else if (_aspectRatio == 0) {
                _aspectRatio = 1;
              } else if (_aspectRatio == 1) {
                _aspectRatio = 16 / 9;
              } else {
                _aspectRatio = -1;
              }

              _cropRect = _applyAspectRatio(_cropRect, _aspectRatio);
            });
          },
          onReset: _resetCrop,
          aspectRatioLabel:
              _aspectRatio == -1
                  ? 'ORIGINAL'
                  : _aspectRatio == 0
                  ? 'FREE'
                  : _aspectRatio == 1
                  ? 'SQUARE'
                  : '16:9',
        );
      default:
        return Center(
          child: Text(
            'Tool Category $_selectedCategory',
            style: const TextStyle(color: Colors.white70),
          ),
        );
    }
  }
}

class _EditTopBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool isSaving;

  const _EditTopBar({
    required this.onCancel,
    required this.onSave,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassButton.custom(
                onTap: onCancel,
                enabled: !isSaving,
                width: 80,
                height: 36,
                useOwnLayer: true,
                settings: AppGlassSettings.premiumButton,
                quality: GlassQuality.premium,
                shape: const LiquidRoundedRectangle(borderRadius: 18),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isSaving ? Colors.white38 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const Text(
                'Edit', // Could be 'Crop' or such depending on mode, but 'Edit' is fine
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              GlassButton.custom(
                onTap: onSave,
                enabled: !isSaving,
                width: 80,
                height: 36,
                useOwnLayer: true,
                settings: AppGlassSettings.premiumButton,
                quality: GlassQuality.premium,
                shape: const LiquidRoundedRectangle(borderRadius: 18),
                child: Center(
                  child:
                      isSaving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber,
                            ),
                          )
                          : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // White style as requested
    final color =
        isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.transparent,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> filters;
  final String? selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final File? imageFile;
  final MediaItem mediaItem;

  const _StyleCarousel({
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.imageFile,
    required this.mediaItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "STANDARD" pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            (selectedFilter ?? 'STANDARD').toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            padding: const EdgeInsets.symmetric(
              horizontal: 110,
            ), // Keeps selected in center-ish
            itemBuilder: (context, index) {
              final filterName = filters[index]['name'];
              final matrix = filters[index]['matrix'] as List<double>;
              final isSelected = selectedFilter == filterName;

              return GestureDetector(
                onTap: () => onFilterSelected(filterName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      // Active indicator dot
                      if (isSelected)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Thumbnail
                      _StyleThumbnail(
                        isSelected: isSelected,
                        imageFile: imageFile,
                        mediaItem: mediaItem,
                        matrixValues: matrix,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StyleThumbnail extends StatelessWidget {
  final bool isSelected;
  final File? imageFile;
  final MediaItem mediaItem;
  final List<double> matrixValues;

  const _StyleThumbnail({
    required this.isSelected,
    this.imageFile,
    required this.mediaItem,
    required this.matrixValues,
  });

  @override
  Widget build(BuildContext context) {
    // Build ColorFilter for thumbnail
    // Similar logic to main filter but only applying the matrix values directly
    // Ideally we should share the exact logic, but for thumbnails simple application is fine.
    // The matrixValues from _styleFilters are [brightness, contrast, saturation, warmth]
    // We need to convert this to a 5x5 matrix using the helper similarly.

    // Copying helper logic for self-contained component or we could make it static.
    // For simplicity, let's just make a simple approximation or pass the builder.
    // Actually, let's use the provided matrix values to build a real matrix.

    final b = matrixValues[0];
    final c = matrixValues[1];
    final s = matrixValues[2];
    final w = matrixValues[3];

    final base = [
      c,
      0.0,
      0.0,
      0.0,
      b * 100 + w * 20,
      0.0,
      c,
      0.0,
      0.0,
      b * 100,
      0.0,
      0.0,
      c,
      0.0,
      b * 100 - w * 20,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // Saturation matrix logic specific to this file's context
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;
    final satMatrix = [
      lumR * (1 - s) + s,
      lumG * (1 - s),
      lumB * (1 - s),
      0.0,
      0.0,
      lumR * (1 - s),
      lumG * (1 - s) + s,
      lumB * (1 - s),
      0.0,
      0.0,
      lumR * (1 - s),
      lumG * (1 - s),
      lumB * (1 - s) + s,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // Multiply
    final m1 = base;
    final m2 = satMatrix;
    final result = List<double>.filled(20, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += m1[i * 5 + k] * m2[k * 5 + j];
        }
        result[i * 5 + j] = sum;
      }
      double tSum = 0;
      for (int k = 0; k < 4; k++) {
        tSum += m1[i * 5 + k] * m2[k * 5 + 4];
      }
      result[i * 5 + 4] = tSum + m1[i * 5 + 4];
    }

    Widget imageContent;
    if (kIsWeb && mediaItem.webUrl != null) {
      imageContent = Image.network(
        mediaItem.webUrl!.replaceAll('/400/400', '/200/200'),
        fit: BoxFit.cover,
      );
    } else if (imageFile != null) {
      imageContent = Image.file(
        imageFile!,
        fit: BoxFit.cover,
        cacheWidth: 150, // Optimize memory
      );
    } else {
      imageContent = Container(color: Colors.grey.shade900);
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4), // Slightly sharper for photos
        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(result),
        child: imageContent,
      ),
    );
  }
}

class _AdjustPanel extends StatelessWidget {
  final AdjustTool selectedTool;
  final ValueChanged<AdjustTool> onToolSelected;
  final double value;
  final ValueChanged<double> onValueChanged;

  const _AdjustPanel({
    required this.selectedTool,
    required this.onToolSelected,
    required this.value,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Dial Slider
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _DialSlider(value: value, onChanged: onValueChanged),
        ),

        // Tool Selector
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AdjustTool.values.length,
            itemBuilder: (context, index) {
              final tool = AdjustTool.values[index];
              final isSelected = tool == selectedTool;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToolSelected(tool);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.grey.withValues(alpha: 0.3),
                        ),
                        child: Icon(
                          tool.icon,
                          color: isSelected ? Colors.black : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 10,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DialSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DialSlider({required this.value, required this.onChanged});

  @override
  State<_DialSlider> createState() => _DialSliderState();
}

class _DialSliderState extends State<_DialSlider> {
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _dragValue = widget.value;
  }

  @override
  void didUpdateWidget(_DialSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _dragValue = widget.value;
    }
  }

  void _handleDrag(DragUpdateDetails details) {
    // Sensitivity: how many pixels per 0.1 value change
    const sensitivity = 20.0;
    final delta = details.primaryDelta ?? 0;

    // Drag Right -> Increase Value
    double newValue = _dragValue + (delta / sensitivity) * 0.1;
    newValue = newValue.clamp(-1.0, 1.0);

    // Haptics
    if ((newValue * 10).truncate() != (_dragValue * 10).truncate()) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      _dragValue = newValue;
    });

    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDrag,
      child: Container(
        height: 50,
        color: Colors.transparent, // Hit test target
        child: CustomPaint(
          size: const Size(0, 50), // Let it expand to fill width naturally
          painter: _DialPainter(value: _dragValue),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double value; // -1.0 to 1.0
  _DialPainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;

    final center = size.width / 2;
    // Spacing between ticks (pixels)
    const spacing = 10.0;

    // Draw center indicator
    canvas.drawLine(
      Offset(center, 0),
      Offset(center, size.height), // Full height line
      Paint()
        ..color = Colors.amber
        ..strokeWidth = 2,
    );

    // Draw ticks
    // Range -1.0 to 1.0.
    // If value is 0, center is 0.
    // If value is 0.1, we shifted by 0.1 units.
    // Pixels per 0.1 unit = spacing.
    // So 1 unit = 10 * spacing.

    final pixelOffset = value * 10 * spacing;

    // Draw generic ruler lines relative to center
    // We want to draw lines for values -1.0 ... 1.0 corresponding to x positions

    for (int i = -20; i <= 20; i++) {
      // i represents 0.1 increments
      // x position relative to center without offset
      final tickX = center + (i * spacing) - pixelOffset;

      // Don't draw if out of bounds (plus some margin)
      if (tickX < -10 || tickX > size.width + 10) continue;

      // Determine height
      double height = 10.0;
      if (i % 5 == 0) height = 20.0; // Major tick (0.5, 1.0)
      if (i % 10 == 0) height = 30.0; // Major tick (1.0)

      // Determine opacity based on distance from center (fade out edges)
      final dist = (tickX - center).abs();
      final maxDist = size.width / 2;
      double opacity = 1.0 - (dist / maxDist);
      opacity = opacity.clamp(0.0, 1.0);

      paint.color = Colors.grey.withValues(alpha: 0.5 * opacity);

      canvas.drawLine(
        Offset(tickX, (size.height - height) / 2),
        Offset(tickX, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) => oldDelegate.value != value;
}

class _VignetteOverlay extends StatelessWidget {
  final double
  intensity; // -1.0 to 1.0 (only positive makes sense for vignette usually)

  const _VignetteOverlay({required this.intensity});

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: intensity.clamp(0.0, 1.0)),
            ],
            stops: const [0.4, 1.0],
            radius: 1.2,
          ),
        ),
      ),
    );
  }
}

class _CropPanel extends StatelessWidget {
  final double straightenAngle;
  final ValueChanged<double> onStraightenChanged;
  final VoidCallback onRotate;
  final VoidCallback onFlip;
  final VoidCallback onRatio;
  final VoidCallback onReset;
  final String aspectRatioLabel;

  const _CropPanel({
    required this.straightenAngle,
    required this.onStraightenChanged,
    required this.onRotate,
    required this.onFlip,
    required this.onRatio,
    required this.onReset,
    required this.aspectRatioLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Straighten Dial
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.crop_rotate, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: _DialSlider(
                  value: straightenAngle / 0.785,
                  onChanged: (v) => onStraightenChanged(v * 0.785),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(straightenAngle * 180 / math.pi).round()}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _GlassIconButton(
                icon: Icons.rotate_90_degrees_cw,
                label: 'Rotate',
                onTap: onRotate,
              ),
            ),
            Expanded(
              child: _GlassIconButton(icon: Icons.flip, label: 'Flip', onTap: onFlip),
            ),
            Expanded(
              child: _GlassIconButton(
                icon: Icons.aspect_ratio,
                label: aspectRatioLabel,
                onTap: onRatio,
              ),
            ),
            Expanded(
              child: _GlassIconButton(
                icon: Icons.restart_alt,
                label: 'Reset',
                onTap: onReset,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton.custom(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      width: double.infinity, // Let it be constrained by the parent Row/Flex
      height: 36,
      quality: GlassQuality.premium,
      useOwnLayer: true,
      settings: AppGlassSettings.premiumButton.copyWith(
        glassColor: Colors.transparent, // Inherit from parent surface
      ),
      shape: const LiquidRoundedRectangle(borderRadius: 18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropOverlay extends StatefulWidget {
  final Rect rect; // normalized
  final ValueChanged<Rect> onRectChanged;

  const _CropOverlay({required this.rect, required this.onRectChanged});

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  bool _isDragging = false;
  int _dragHandle = -1; // -1: none, 0: center, 1: TL, 2: TR, 3: BL, 4: BR

  void _onDragStart(DragStartDetails details, Size size) {
    _isDragging = true;
    final r = widget.rect;
    final pos = details.localPosition;

    // Map normalized rect to screen coords
    final screenRect = Rect.fromLTWH(
      r.left * size.width,
      r.top * size.height,
      r.width * size.width,
      r.height * size.height,
    );

    // Hit test corners (radius 30)
    const rad = 30.0;
    if ((pos - screenRect.topLeft).distance < rad) {
      _dragHandle = 1;
    } else if ((pos - screenRect.topRight).distance < rad) {
      _dragHandle = 2;
    } else if ((pos - screenRect.bottomLeft).distance < rad) {
      _dragHandle = 3;
    } else if ((pos - screenRect.bottomRight).distance < rad) {
      _dragHandle = 4;
    } else if (screenRect.contains(pos)) {
      _dragHandle = 0; // Check center last
    } else {
      _dragHandle = -1;
    }
  }

  void _onDragUpdate(DragUpdateDetails details, Size size) {
    if (_dragHandle == -1) return;

    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;

    Rect newRect = widget.rect;

    if (_dragHandle == 0) {
      // Pan
      newRect = newRect.translate(dx, dy);
    } else {
      // Resize
      double l = newRect.left;
      double t = newRect.top;
      double r = newRect.right;
      double b = newRect.bottom;

      if (_dragHandle == 1) {
        l += dx;
        t += dy;
      } // TL
      if (_dragHandle == 2) {
        r += dx;
        t += dy;
      } // TR
      if (_dragHandle == 3) {
        l += dx;
        b += dy;
      } // BL
      if (_dragHandle == 4) {
        r += dx;
        b += dy;
      } // BR

      // Enforce min size
      if (r < l + 0.1) r = l + 0.1;
      if (b < t + 0.1) b = t + 0.1;

      newRect = Rect.fromLTRB(l, t, r, b);
    }

    // Clamp to 0..1
    newRect = newRect.intersect(const Rect.fromLTWH(0, 0, 1, 1));

    widget.onRectChanged(newRect);
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _dragHandle = -1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onPanStart: (d) => _onDragStart(d, size),
          onPanUpdate: (d) => _onDragUpdate(d, size),
          onPanEnd: _onDragEnd,
          child: Container(
            color: Colors.transparent, // Hit test entire area
            child: CustomPaint(
              painter: _GridPainter(rect: widget.rect, isDragging: _isDragging),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final Rect rect; // normalized
  final bool isDragging;

  _GridPainter({required this.rect, required this.isDragging});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Dimmed Outer Area
    // Intersect the screen rect with crop rect to find the hole.
    // Or just draw 4 rectangles around.

    final screenRect = Offset.zero & size;
    final cropRectScreen = Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );

    final paintObj = Paint()..color = Colors.black.withValues(alpha: 0.5);

    // Path operation: Screen - Crop
    final outerPath =
        Path()
          ..fillType =
              PathFillType
                  .evenOdd // Fix: fillType belongs to Path
          ..addRect(screenRect)
          ..addRect(cropRectScreen);

    canvas.drawPath(outerPath, paintObj);

    // 2. Draw Grid
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: isDragging ? 0.6 : 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    // Draw Box
    canvas.drawRect(cropRectScreen, gridPaint);

    // Thirds
    final w = cropRectScreen.width;
    final h = cropRectScreen.height;
    final l = cropRectScreen.left;
    final t = cropRectScreen.top;

    canvas.drawLine(Offset(l + w / 3, t), Offset(l + w / 3, t + h), gridPaint);
    canvas.drawLine(
      Offset(l + 2 * w / 3, t),
      Offset(l + 2 * w / 3, t + h),
      gridPaint,
    );
    canvas.drawLine(Offset(l, t + h / 3), Offset(l + w, t + h / 3), gridPaint);
    canvas.drawLine(
      Offset(l, t + 2 * h / 3),
      Offset(l + w, t + 2 * h / 3),
      gridPaint,
    );

    // 3. Draw Corners (Thick)
    final cornerPaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    final path = Path();
    const len = 20.0;

    // TL
    path.moveTo(l, t + len);
    path.lineTo(l, t);
    path.lineTo(l + len, t);
    // TR
    path.moveTo(l + w - len, t);
    path.lineTo(l + w, t);
    path.lineTo(l + w, t + len);
    // BR
    path.moveTo(l + w, t + h - len);
    path.lineTo(l + w, t + h);
    path.lineTo(l + w - len, t + h);
    // BL
    path.moveTo(l + len, t + h);
    path.lineTo(l, t + h);
    path.lineTo(l, t + h - len);

    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.isDragging != isDragging;
}
