import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/enhance_image_controller.dart';

class EnhanceImageScreen extends StatefulWidget {
  final String? initialImagePath;
  const EnhanceImageScreen({super.key, this.initialImagePath});

  @override
  State<EnhanceImageScreen> createState() => _EnhanceImageScreenState();
}

class _EnhanceImageScreenState extends State<EnhanceImageScreen> {
  final EnhanceImageController _c = Get.put(EnhanceImageController());

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textPrimary = Color(0xFF1A1D2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _brandOrange = Color(0xFFFF8C42);
  static const Color _brandTeal = Color(0xFF0D9488);

  // Split-screen Before/After Slider position (0.0 to 1.0)
  double _splitPosition = 0.5;
  bool _showCustomSliders = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null &&
        File(widget.initialImagePath!).existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.loadImage(widget.initialImagePath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_fix_high_rounded,
                color: _brandOrange, size: 22),
            SizedBox(width: 8),
            Text(
              'AI Image Enhancer',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (!_c.hasImage) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rotate 90
                IconButton(
                  icon: const Icon(Icons.rotate_right_rounded,
                      size: 22, color: _textPrimary),
                  tooltip: 'Rotate 90°',
                  onPressed: _c.isProcessing.value ? null : _c.rotate90,
                ),
                // Change / Reset
                TextButton.icon(
                  onPressed: _c.isProcessing.value ? null : _c.reset,
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: _brandOrange),
                  label: const Text(
                    'Change',
                    style: TextStyle(
                      color: _brandOrange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (!_c.hasImage) {
          return _buildEmptyState();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (!_c.hasImage) return const BottomNativeAd();
        return _buildBottomBar();
      }),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. EMPTY STATE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing AI Magic Wand Icon
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandOrange.withValues(alpha: 0.22),
                    const Color(0xFF6366F1).withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandOrange.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandOrange.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_fix_high_rounded,
                size: 50,
                color: _brandOrange,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),
            const Text(
              'Enhance Photos & Documents',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Auto-fix blurry photos, clean document paper shadows,\nboost vibrant colors, and sharpen details in 1 tap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            // Source Option 1: Gallery
            _buildSourceCard(
              icon: Icons.photo_library_rounded,
              color: _brandOrange,
              title: 'Select from Gallery',
              subtitle: 'Enhance portraits, landscapes, receipts or photos',
              onTap: _c.pickFromGallery,
            ),
            const SizedBox(height: 12),

            // Source Option 2: Camera
            _buildSourceCard(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF6366F1),
              title: 'Take a Photo',
              subtitle: 'Capture document or note & enhance with AI',
              onTap: _c.captureFromCamera,
            ),

            const SizedBox(height: 24),

            // Feature List
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildFeatureRow(
                    icon: Icons.auto_awesome_rounded,
                    color: _brandOrange,
                    title: 'One-Tap AI Magic Fix',
                    desc: 'Auto-adjusts contrast, sharpness, and brightness',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.document_scanner_rounded,
                    color: _brandTeal,
                    title: 'Crisp Document Scan Mode',
                    desc: 'Cleans up dark background shadows & enhances text readability',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.filter_vintage_rounded,
                    color: const Color(0xFFEC4899),
                    title: 'Vivid HDR Color Pop',
                    desc: 'Rich dynamic saturation and high-definition tones',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.compare_rounded,
                    color: const Color(0xFF3B82F6),
                    title: 'Interactive Before/After Slider',
                    desc: 'Swipe left and right to see instant comparison',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _c.isPicking.value ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 11.5, color: _textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. ACTIVE ENHANCER WORKSPACE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildWorkspace() {
    return Column(
      children: [
        // ── Top Split Comparison Canvas ────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildComparisonCanvas(),
            ),
          ),
        ),

        // ── Preset Selector & Manual Controls ──────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Presets Ribbon Header with Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Enhancement Filters',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showCustomSliders = !_showCustomSliders;
                        });
                      },
                      icon: Icon(
                        _showCustomSliders
                            ? Icons.grid_view_rounded
                            : Icons.tune_rounded,
                        size: 16,
                        color: _brandOrange,
                      ),
                      label: Text(
                        _showCustomSliders ? 'Presets' : 'Tune Sliders',
                        style: const TextStyle(
                          color: _brandOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Presets Ribbon OR Custom Sliders
              if (_showCustomSliders)
                _buildCustomTuningSliders()
              else
                _buildPresetsRibbon(),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. INTERACTIVE BEFORE / AFTER COMPARISON CANVAS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildComparisonCanvas() {
    final origBytes = _c.originalImageBytes.value;
    final enhBytes = _c.enhancedImageBytes.value ?? origBytes;

    if (origBytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: _brandOrange),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        return Stack(
          children: [
            // 1. Base Layer: Original Image
            Positioned.fill(
              child: Image.memory(
                origBytes,
                fit: BoxFit.contain,
              ),
            ),

            // 2. Top Layer: Enhanced Image (Clipped to split position)
            if (enhBytes != null)
              Positioned.fill(
                child: ClipRect(
                  clipper: _SplitClipper(_splitPosition),
                  child: Image.memory(
                    enhBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            // 3. Vertical Divider Line with Drag Grip
            Positioned(
              left: w * _splitPosition - 16,
              top: 0,
              bottom: 0,
              width: 32,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _splitPosition = (_splitPosition + details.delta.dx / w)
                        .clamp(0.05, 0.95);
                  });
                },
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // White vertical line
                      Container(
                        width: 2.5,
                        color: Colors.white,
                      ),
                      // Circular Thumb Handle
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _brandOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Badges: "Original" (Left) and "Enhanced" (Right)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Original',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _brandOrange.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Enhanced',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Processing indicator overlay
            if (_c.isProcessing.value)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: _brandOrange,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. PRESETS RIBBON
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildPresetsRibbon() {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: EnhancePreset.values.length,
        itemBuilder: (context, index) {
          final preset = EnhancePreset.values[index];
          if (preset == EnhancePreset.custom) return const SizedBox.shrink();

          return Obx(() {
            final isSel = _c.selectedPreset.value == preset;
            return InkWell(
              onTap: _c.isProcessing.value
                  ? null
                  : () => _c.selectPreset(preset),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 82,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSel
                      ? preset.color.withValues(alpha: 0.12)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSel ? preset.color : const Color(0xFFE2E8F0),
                    width: isSel ? 2 : 1,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: preset.color.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: preset.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(preset.icon,
                          color: preset.color, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSel ? preset.color : _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. CUSTOM TUNING SLIDERS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildCustomTuningSliders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSliderRow(
            icon: Icons.brightness_6_rounded,
            label: 'Brightness',
            value: _c.brightness.value,
            min: -50,
            max: 50,
            onChanged: (val) {
              _c.brightness.value = val;
              _c.onSliderChanged();
            },
          ),
          _buildSliderRow(
            icon: Icons.contrast_rounded,
            label: 'Contrast',
            value: (_c.contrast.value - 1.0) * 50,
            min: -50,
            max: 50,
            onChanged: (val) {
              _c.contrast.value = 1.0 + (val / 50.0);
              _c.onSliderChanged();
            },
          ),
          _buildSliderRow(
            icon: Icons.details_rounded,
            label: 'Sharpness',
            value: _c.sharpness.value,
            min: 0,
            max: 100,
            onChanged: (val) {
              _c.sharpness.value = val;
              _c.onSliderChanged();
            },
          ),
          _buildSliderRow(
            icon: Icons.palette_rounded,
            label: 'Saturation',
            value: _c.saturation.value,
            min: -50,
            max: 50,
            onChanged: (val) {
              _c.saturation.value = val;
              _c.onSliderChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                activeColor: _brandOrange,
                inactiveColor: const Color(0xFFE2E8F0),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. BOTTOM BAR (SHARE / SAVE)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: _brandOrange.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _c.isProcessing.value
                    ? null
                    : () {
                        _c.shareEnhancedImage();
                      },
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text(
                  'Share Enhanced Image',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Split Clipper for Before/After Slider ──────────────────────────────
class _SplitClipper extends CustomClipper<Rect> {
  final double splitRatio;
  _SplitClipper(this.splitRatio);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      size.width * splitRatio,
      0,
      size.width,
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant _SplitClipper oldClipper) {
    return oldClipper.splitRatio != splitRatio;
  }
}
