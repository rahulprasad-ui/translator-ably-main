import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/compress_image_controller.dart';

class CompressImageScreen extends StatefulWidget {
  final List<String>? initialImagePaths;
  const CompressImageScreen({super.key, this.initialImagePaths});

  @override
  State<CompressImageScreen> createState() => _CompressImageScreenState();
}

class _CompressImageScreenState extends State<CompressImageScreen> {
  final CompressImageController _c = Get.put(CompressImageController());

  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _textPrimary = Color(0xFF1A1D2E);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _brandOrange = Color(0xFFFF8C42);
  static const Color _brandTeal = Color(0xFF0D9488);
  static const Color _accentGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePaths != null &&
        widget.initialImagePaths!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Preload passed images if any
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
            Icon(Icons.photo_size_select_small_rounded,
                color: _brandOrange, size: 24),
            SizedBox(width: 8),
            Text(
              'Compress Images',
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
            if (_c.images.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isCompressing.value ? null : _c.reset,
              icon: const Icon(Icons.refresh_rounded,
                  size: 18, color: _brandOrange),
              label: const Text(
                'Reset',
                style: TextStyle(
                  color: _brandOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (_c.images.isEmpty) {
          return _buildEmptyState();
        }
        return _buildWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (_c.images.isEmpty) return const BottomNativeAd();
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
            // Glowing Compressor Icon
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandOrange.withValues(alpha: 0.2),
                    _brandTeal.withValues(alpha: 0.12),
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
                Icons.compress_rounded,
                size: 50,
                color: _brandOrange,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

            const SizedBox(height: 20),
            const Text(
              'Compress & Optimize Images',
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
              'Reduce image file size up to 90% without losing quality.\nSupports batch compression for multiple photos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            // Option 1: Gallery Multi-Select
            _buildSourceCard(
              icon: Icons.photo_library_rounded,
              color: _brandOrange,
              title: 'Select from Gallery',
              subtitle: 'Choose one or multiple photos to compress together',
              onTap: () => _c.pickFromGallery(append: false),
            ),
            const SizedBox(height: 12),

            // Option 2: Camera Capture
            _buildSourceCard(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF6366F1),
              title: 'Take a Photo',
              subtitle: 'Capture high-res camera photo & compress instantly',
              onTap: _c.captureFromCamera,
            ),

            const SizedBox(height: 24),

            // Feature Highlights
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
                    icon: Icons.speed_rounded,
                    color: _accentGreen,
                    title: 'Ultra Fast Batch Processing',
                    desc: 'Optimized multi-threaded compression engine',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.tune_rounded,
                    color: const Color(0xFF3B82F6),
                    title: 'Custom Quality & Resolution',
                    desc: 'Adjust compression ratio & resize images to exact target',
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _buildFeatureRow(
                    icon: Icons.compare_rounded,
                    color: _brandOrange,
                    title: 'Instant Before/After Preview',
                    desc: 'Compare original and compressed images side-by-side',
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
  // 2. ACTIVE WORKSPACE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildWorkspace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dashboard Metrics Card ───────────────────────────────────────
          _buildMetricsCard(),

          const SizedBox(height: 18),

          // ── Presets Section ──────────────────────────────────────────────
          const Text(
            'Compression Level',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildPresetSelector(),

          // Custom Controls (if custom preset is active)
          Obx(() {
            if (_c.selectedPreset.value != ImageCompressPreset.custom) {
              return const SizedBox.shrink();
            }
            return _buildCustomSettingsPanel();
          }),

          const SizedBox(height: 20),

          // ── Selected Images Header ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Images (${_c.images.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: _c.isCompressing.value
                    ? null
                    : () => _c.pickFromGallery(append: true),
                icon: const Icon(Icons.add_photo_alternate_rounded,
                    size: 18, color: _brandTeal),
                label: const Text(
                  'Add More',
                  style: TextStyle(
                    color: _brandTeal,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Image Items List ─────────────────────────────────────────────
          ..._c.images.map((item) => _buildImageItemCard(item)),

          const SizedBox(height: 80), // Bottom padding for FAB bar
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. METRICS DASHBOARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMetricsCard() {
    final isDone = _c.isFinished.value;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDone
              ? [const Color(0xFF0F766E), const Color(0xFF0D9488)]
              : [const Color(0xFF1E293B), const Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDone ? _brandTeal : Colors.black)
                .withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDone ? 'Total Saved' : 'Total Size',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDone
                        ? _c.formattedTotalSavedSize
                        : _c.formattedTotalOriginalSize,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (isDone && _c.overallSavingsPercentage > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_c.overallSavingsPercentage}% Smaller',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_c.images.length} Photos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (isDone) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Original: ${_c.formattedTotalOriginalSize}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Compressed: ${_c.formattedTotalCompressedSize}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. PRESET SELECTOR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildPresetSelector() {
    return Column(
      children: ImageCompressPreset.values.map((preset) {
        return Obx(() {
          final isSelected = _c.selectedPreset.value == preset;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _c.isCompressing.value
                  ? null
                  : () {
                      _c.selectedPreset.value = preset;
                    },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? preset.color.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? preset.color
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: preset.color.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: preset.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(preset.icon, color: preset.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? preset.color : _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preset.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Radio<ImageCompressPreset>(
                      value: preset,
                      groupValue: _c.selectedPreset.value,
                      activeColor: preset.color,
                      onChanged: _c.isCompressing.value
                          ? null
                          : (val) {
                              if (val != null) _c.selectedPreset.value = val;
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }).toList(),
    );
  }

  Widget _buildCustomSettingsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quality Slider',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Obx(() => Text(
                    '${_c.customQuality.value}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _brandOrange,
                    ),
                  )),
            ],
          ),
          Obx(() => Slider(
                value: _c.customQuality.value.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                activeColor: _brandOrange,
                inactiveColor: const Color(0xFFE2E8F0),
                onChanged: (val) => _c.customQuality.value = val.round(),
              )),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Resize Resolution Limit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Obx(() => Switch(
                    value: _c.resizeEnabled.value,
                    activeColor: _brandTeal,
                    onChanged: (val) => _c.resizeEnabled.value = val,
                  )),
            ],
          ),
          Obx(() {
            if (!_c.resizeEnabled.value) return const SizedBox.shrink();
            return Row(
              children: [
                _buildResolutionChip(1080, '1080p FHD'),
                const SizedBox(width: 8),
                _buildResolutionChip(1920, '1920p 2K'),
                const SizedBox(width: 8),
                _buildResolutionChip(2560, '2560p 4K'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResolutionChip(int width, String label) {
    return Obx(() {
      final isSel = _c.customMaxWidth.value == width;
      return GestureDetector(
        onTap: () => _c.customMaxWidth.value = width,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? _brandTeal.withValues(alpha: 0.15) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? _brandTeal : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSel ? _brandTeal : _textSecondary,
            ),
          ),
        ),
      );
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. IMAGE ITEM CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildImageItemCard(CompressImageItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isCompleted
              ? _accentGreen.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 54,
              height: 54,
              color: const Color(0xFFF1F5F9),
              child: item.thumbnailBytes != null
                  ? Image.memory(
                      item.thumbnailBytes!,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.image, color: Colors.black26),
            ),
          ),
          const SizedBox(width: 12),

          // Name and Sizes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      item.formattedOriginalSize,
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isCompleted
                            ? _textSecondary
                            : _textPrimary,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (item.isCompleted && item.compressedSizeBytes != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 14, color: _accentGreen),
                      const SizedBox(width: 6),
                      Text(
                        item.formattedCompressedSize,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _accentGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Savings Badge or Action
          if (item.isCompleted && item.savingsPercentage > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-${item.savingsPercentage}%',
                style: const TextStyle(
                  color: _accentGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (item.isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _brandOrange,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: Color(0xFF94A3B8)),
              onPressed: () => _c.removeImage(item.id),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 6. BOTTOM ACTION BAR
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    final isProcessing = _c.isCompressing.value;
    final isDone = _c.isFinished.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isProcessing) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _c.currentStep.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _c.cancelCompression,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: _c.progress.value,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(_brandOrange),
                borderRadius: BorderRadius.circular(4),
              ),
            ] else if (isDone) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: _brandTeal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _c.reset,
                      icon: const Icon(Icons.add_photo_alternate_rounded,
                          color: _brandTeal, size: 20),
                      label: const Text(
                        'Compress New',
                        style: TextStyle(
                          color: _brandTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _c.shareAllCompressed,
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: Text(
                        'Share All (${_c.images.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandOrange,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: _brandOrange.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _c.startCompression,
                  icon: const Icon(Icons.bolt_rounded, size: 22),
                  label: Text(
                    'Compress ${_c.images.length} ${_c.images.length == 1 ? "Image" : "Images"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
