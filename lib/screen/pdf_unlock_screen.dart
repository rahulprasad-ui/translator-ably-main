// lib/screen/pdf_unlock_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/pdf_unlock_controller.dart';
import '../helper/my_dialogs.dart';

class PdfUnlockScreen extends StatefulWidget {
  final String? initialPdfPath;
  const PdfUnlockScreen({super.key, this.initialPdfPath});

  @override
  State<PdfUnlockScreen> createState() => _PdfUnlockScreenState();
}

class _PdfUnlockScreenState extends State<PdfUnlockScreen> {
  final PdfUnlockController _c = Get.put(PdfUnlockController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _brandEmerald = Color(0xFF10B981);
  static const Color _brandEmeraldDark = Color(0xFF059669);
  static const Color _brandTeal = Color(0xFF0D9488);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    if (widget.initialPdfPath != null &&
        File(widget.initialPdfPath!).existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.inspectAndLoadPdf(widget.initialPdfPath!);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _textPrimary, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open_rounded, color: _brandEmerald, size: 22),
            SizedBox(width: 8),
            Text(
              'Unlock PDF',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            if (!_c.hasDocument) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: _c.isExporting.value || _c.isProcessing.value
                  ? null
                  : _c.pickPdfFile,
              icon: const Icon(Icons.folder_open_rounded,
                  size: 18, color: _brandEmerald),
              label: const Text(
                'Change',
                style: TextStyle(
                  color: _brandEmerald,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (_c.isPicking.value) {
          return const Center(
            child: CircularProgressIndicator(color: _brandEmerald),
          );
        }
        if (!_c.hasDocument) {
          return _buildEmptyState();
        }
        if (_c.unlockStatus.value == UnlockStatus.checkingEncryption) {
          return _buildCheckingState();
        }
        if (_c.unlockStatus.value == UnlockStatus.unlockedSuccess) {
          return _buildUnlockedSuccessView();
        }
        if (_c.unlockStatus.value == UnlockStatus.alreadyUnlocked) {
          return _buildAlreadyUnlockedView();
        }
        return _buildPasswordInputWorkspace();
      }),
      bottomNavigationBar: Obx(() {
        if (!_c.hasDocument ||
            _c.unlockStatus.value == UnlockStatus.unlockedSuccess ||
            _c.unlockStatus.value == UnlockStatus.alreadyUnlocked) {
          return const BottomNativeAd();
        }
        return const SizedBox.shrink();
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
            // Hero Icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _brandEmerald.withValues(alpha: 0.18),
                    _brandTeal.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _brandEmerald.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandEmerald.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                size: 52,
                color: _brandEmerald,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Unlock PDF Password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Permanently remove passwords, encryption and permission restrictions\nfrom your PDF documents so you can open them anywhere without a password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 32),

            // Select PDF Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _c.pickPdfFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandEmerald,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandEmerald.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: const Text(
                  'Select Password-Protected PDF',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Feature Highlights
            _buildFeaturePill(
              icon: Icons.vpn_key_off_rounded,
              title: 'Permanent Password Removal',
              subtitle: 'Never enter passwords again when opening or printing',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.print_rounded,
              title: 'Enable Full Permissions',
              subtitle: 'Removes restrictions on printing, editing, and copying text',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.speed_rounded,
              title: 'Instant Decryption',
              subtitle: 'High-speed hardware-accelerated decryption engine',
            ),
            const SizedBox(height: 12),
            _buildFeaturePill(
              icon: Icons.shield_outlined,
              title: '100% Offline & Secure',
              subtitle: 'Processed entirely on your device with complete privacy',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _brandEmerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _brandEmerald, size: 20),
          ),
          const SizedBox(width: 14),
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
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _brandEmerald),
          const SizedBox(height: 20),
          const Text(
            'Analyzing PDF Encryption...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _c.selectedPdfName.value ?? 'document.pdf',
            style: const TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. PASSWORD INPUT WORKSPACE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildPasswordInputWorkspace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFEF4444),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _c.selectedPdfName.value ?? 'document.pdf',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Locked',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _c.formattedFileSize,
                            style: const TextStyle(
                                fontSize: 12, color: _textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Enter Document Password',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the current password once. Our engine will decrypt the document and remove the password permanently.',
            style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.4),
          ),

          const SizedBox(height: 18),

          // Password Field
          Obx(() {
            final isVisible = _c.isPasswordVisible.value;
            return TextField(
              controller: _c.passwordController,
              autofocus: true,
              obscureText: !isVisible,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Enter PDF password',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.key_rounded,
                    color: _brandEmerald, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _textSecondary,
                    size: 20,
                  ),
                  onPressed: () => _c.isPasswordVisible.value = !isVisible,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _brandEmerald, width: 2),
                ),
              ),
              onSubmitted: (_) => _c.unlockWithPassword(),
            );
          }),

          // Error Message
          Obx(() {
            final err = _c.errorMessage.value;
            if (err == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      err,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 28),

          // Unlock & Export Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Obx(() {
              final isWorking =
                  _c.isProcessing.value || _c.isExporting.value;
              return ElevatedButton.icon(
                onPressed: isWorking ? null : _c.unlockWithPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandEmerald,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _brandEmerald.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isWorking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 22),
                label: Text(
                  isWorking ? 'Decrypting Document...' : 'Unlock & Remove Password',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. UNLOCKED SUCCESS VIEW
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildUnlockedSuccessView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            // Success Badge
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _brandEmerald.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _brandEmerald,
                size: 56,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'PDF Successfully Unlocked!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Password protection and all security restrictions have been permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Decrypted Preview Card
            Obx(() {
              final bytes = _c.previewPageBytes.value;
              if (bytes == null) return const SizedBox.shrink();
              return Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              );
            }),

            const SizedBox(height: 28),

            // Share & Done Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brandEmerald,
                      side: const BorderSide(color: _brandEmerald, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final path = _c.unlockedPdfPath.value;
                      if (path != null) {
                        MyDialogs.success(msg: 'Saved to $path');
                      }
                      Get.back();
                    },
                    icon: const Icon(Icons.done_rounded, size: 18),
                    label: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandEmerald,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _c.shareUnlockedPdf,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(
                      'Share PDF',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. ALREADY UNLOCKED VIEW
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildAlreadyUnlockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Color(0xFF3B82F6),
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Password Required!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This PDF document is already unlocked and has no password protection or encryption restrictions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.45),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _c.pickPdfFile,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Select Another PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
