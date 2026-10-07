// lib/screen/qr_generator_screen.dart
import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';

import '../ads/widget/bottom_native_ad.dart';
import '../controllers/qr_generator_controller.dart';
import '../helper/my_dialogs.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final QrGeneratorController _c = Get.put(QrGeneratorController());

  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _brandPurple = Color(0xFF7C3AED);
  static const Color _brandIndigo = Color(0xFF4F46E5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

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
            Icon(Icons.qr_code_2_rounded, color: _brandPurple, size: 24),
            SizedBox(width: 8),
            Text(
              'QR Code Generator',
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
            if (_c.recentQrs.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.history_rounded,
                  color: _brandPurple, size: 22),
              tooltip: 'Recent QR Codes',
              onPressed: _showRecentQrsModal,
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Interactive QR Preview Card
            _buildQrPreviewCard(),

            const SizedBox(height: 20),

            // 2. Data Type Horizontal Selector
            _buildTypeSelector(),

            const SizedBox(height: 18),

            // 3. Dynamic Input Form Fields
            _buildInputFields(),

            const SizedBox(height: 22),

            // 4. Color & Badge Customization
            _buildCustomizationSection(),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. LIVE QR PREVIEW CARD
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildQrPreviewCard() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // QR Code CustomPaint Canvas
            Obx(() {
              final payload = _c.currentPayload;
              final color = _c.qrColor.value;
              final bgColor = _c.qrBgColor.value;
              final icon = _c.selectedCenterIcon.value;

              return Container(
                width: 210,
                height: 210,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.18), width: 1.2),
                ),
                child: CustomPaint(
                  size: const Size(186, 186),
                  painter: _QrCanvasPainter(
                    data: payload,
                    color: color,
                    centerIcon: icon,
                  ),
                ),
              );
            }),

            const SizedBox(height: 14),

            // Title / Type Indicator
            Obx(() => Text(
                  _c.currentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                )),

            const SizedBox(height: 4),

            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  'Standard Scan-Ready QR Format',
                  style: TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Quick Actions Strip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionBtn(
                  icon: Icons.copy_rounded,
                  label: 'Copy Content',
                  onTap: _c.copyPayload,
                ),
                Container(width: 1, height: 20, color: Colors.grey.withValues(alpha: 0.2)),
                _buildQuickActionBtn(
                  icon: Icons.image_rounded,
                  label: 'Save Image',
                  onTap: _c.saveQrImage,
                ),
                Container(width: 1, height: 20, color: Colors.grey.withValues(alpha: 0.2)),
                _buildQuickActionBtn(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: _c.shareQrCode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 15, color: _brandPurple),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _brandPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. DATA TYPE SELECTOR (URL, Text, WiFi, Contact, etc.)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select QR Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Obx(() {
            final sel = _c.selectedType.value;
            return Row(
              children: [
                _buildTypeChip(QrDataType.url, 'URL / Link', Icons.link_rounded, sel),
                const SizedBox(width: 8),
                _buildTypeChip(QrDataType.text, 'Plain Text', Icons.notes_rounded, sel),
                const SizedBox(width: 8),
                _buildTypeChip(QrDataType.wifi, 'Wi-Fi Network', Icons.wifi_rounded, sel),
                const SizedBox(width: 8),
                _buildTypeChip(QrDataType.contact, 'vCard Contact', Icons.badge_rounded, sel),
                const SizedBox(width: 8),
                _buildTypeChip(QrDataType.email, 'Email', Icons.mail_rounded, sel),
                const SizedBox(width: 8),
                _buildTypeChip(QrDataType.phone, 'Phone / SMS', Icons.phone_rounded, sel),
                const SizedBox(width: 8),
                _buildTypeChip(QrDataType.upi, 'UPI Payment', Icons.currency_rupee_rounded, sel),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTypeChip(
      QrDataType type, String label, IconData icon, QrDataType selected) {
    final isSel = type == selected;
    return GestureDetector(
      onTap: () => _c.selectedType.value = type,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? _brandPurple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? _brandPurple : Colors.grey.withValues(alpha: 0.22),
          ),
          boxShadow: isSel
              ? [
                  BoxShadow(
                    color: _brandPurple.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSel ? Colors.white : _textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                color: isSel ? Colors.white : _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 3. DYNAMIC INPUT FORM FIELDS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildInputFields() {
    return Obx(() {
      switch (_c.selectedType.value) {
        case QrDataType.url:
          return _buildInputField(
            controller: _c.urlController,
            label: 'Website URL',
            hint: 'https://example.com',
            icon: Icons.link_rounded,
            keyboardType: TextInputType.url,
          );

        case QrDataType.text:
          return _buildInputField(
            controller: _c.textController,
            label: 'Message / Text Content',
            hint: 'Enter your notes, quotes, or text...',
            icon: Icons.notes_rounded,
            maxLines: 3,
          );

        case QrDataType.wifi:
          return Column(
            children: [
              _buildInputField(
                controller: _c.wifiSsidController,
                label: 'Network Name (SSID)',
                hint: 'e.g. Home_WiFi',
                icon: Icons.wifi_rounded,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.wifiPasswordController,
                label: 'Wi-Fi Password',
                hint: 'Password (leave blank if open)',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Security:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textSecondary)),
                  const SizedBox(width: 10),
                  _buildSecChip('WPA/WPA2', 'WPA'),
                  const SizedBox(width: 6),
                  _buildSecChip('WEP', 'WEP'),
                  const SizedBox(width: 6),
                  _buildSecChip('None', 'nopass'),
                ],
              ),
            ],
          );

        case QrDataType.contact:
          return Column(
            children: [
              _buildInputField(
                controller: _c.contactNameController,
                label: 'Full Name',
                hint: 'John Doe',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.contactPhoneController,
                label: 'Phone Number',
                hint: '+91 9876543210',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.contactEmailController,
                label: 'Email Address',
                hint: 'john@example.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.contactOrgController,
                label: 'Company / Organization',
                hint: 'Acme Corp',
                icon: Icons.business_rounded,
              ),
            ],
          );

        case QrDataType.email:
          return Column(
            children: [
              _buildInputField(
                controller: _c.emailToController,
                label: 'Recipient Email',
                hint: 'user@example.com',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.emailSubjectController,
                label: 'Subject',
                hint: 'e.g. Project Inquiry',
                icon: Icons.subject_rounded,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.emailBodyController,
                label: 'Message Body',
                hint: 'Enter your email message...',
                icon: Icons.edit_note_rounded,
                maxLines: 2,
              ),
            ],
          );

        case QrDataType.phone:
          return Column(
            children: [
              _buildInputField(
                controller: _c.phoneController,
                label: 'Phone Number',
                hint: '+91 9876543210',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.smsMessageController,
                label: 'Pre-filled SMS Message (Optional)',
                hint: 'e.g. Hello!',
                icon: Icons.sms_rounded,
              ),
            ],
          );

        case QrDataType.upi:
          return Column(
            children: [
              _buildInputField(
                controller: _c.upiIdController,
                label: 'UPI ID (VPA)',
                hint: 'merchant@upi',
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.upiNameController,
                label: 'Payee Name',
                hint: 'Store or Person Name',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _c.upiAmountController,
                label: 'Amount in INR (Optional)',
                hint: '100',
                icon: Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          );
      }
    });
  }

  Widget _buildSecChip(String label, String val) {
    final isSel = _c.wifiSecurity.value == val;
    return GestureDetector(
      onTap: () => _c.wifiSecurity.value = val,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? _brandPurple : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? Colors.white : _textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _brandPurple, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 4. COLOR & BADGE CUSTOMIZATION
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildCustomizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QR Color Theme',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Color circles
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Obx(() {
            final current = _c.qrColor.value;
            return Row(
              children: [
                _buildColorDot(const Color(0xFF0F172A), 'Midnight', current),
                const SizedBox(width: 10),
                _buildColorDot(const Color(0xFF4F46E5), 'Indigo', current),
                const SizedBox(width: 10),
                _buildColorDot(const Color(0xFF059669), 'Emerald', current),
                const SizedBox(width: 10),
                _buildColorDot(const Color(0xFFE11D48), 'Crimson', current),
                const SizedBox(width: 10),
                _buildColorDot(const Color(0xFF2563EB), 'Blue', current),
                const SizedBox(width: 10),
                _buildColorDot(const Color(0xFFD97706), 'Amber', current),
                const SizedBox(width: 10),
                _buildColorDot(const Color(0xFF7C3AED), 'Purple', current),
              ],
            );
          }),
        ),

        const SizedBox(height: 18),

        const Text(
          'Center Badge Icon',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Badge icon selector
        Obx(() {
          final curIcon = _c.selectedCenterIcon.value;
          return Row(
            children: [
              _buildBadgeIconBtn(null, Icons.block_rounded, curIcon),
              const SizedBox(width: 8),
              _buildBadgeIconBtn(Icons.link_rounded, Icons.link_rounded, curIcon),
              const SizedBox(width: 8),
              _buildBadgeIconBtn(Icons.wifi_rounded, Icons.wifi_rounded, curIcon),
              const SizedBox(width: 8),
              _buildBadgeIconBtn(
                  Icons.person_rounded, Icons.person_rounded, curIcon),
              const SizedBox(width: 8),
              _buildBadgeIconBtn(Icons.mail_rounded, Icons.mail_rounded, curIcon),
              const SizedBox(width: 8),
              _buildBadgeIconBtn(Icons.star_rounded, Icons.star_rounded, curIcon),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildColorDot(Color color, String label, Color selected) {
    final isSel = color == selected;
    return GestureDetector(
      onTap: () => _c.qrColor.value = color,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? _brandPurple : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSel
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildBadgeIconBtn(
      IconData? icon, IconData displayIcon, IconData? current) {
    final isSel = icon == current;
    return GestureDetector(
      onTap: () => _c.selectedCenterIcon.value = icon,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSel ? _brandPurple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? _brandPurple : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          displayIcon,
          size: 20,
          color: isSel ? Colors.white : _textSecondary,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 5. BOTTOM ACTION BAR (Save HD PNG & Printable PDF)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildBottomActionBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BottomNativeAd(),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
        top: false,
        child: Row(
          children: [
            // Save PNG Image
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandPurple,
                    side: const BorderSide(color: _brandPurple, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _c.saveQrImage,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Save HD PNG',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Export Printable PDF
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandPurple,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _c.exportPrintablePdf,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'Printable PDF',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    ],
  );
  }

  void _showRecentQrsModal() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: _brandPurple),
                  SizedBox(width: 8),
                  Text(
                    'Recent Generated QR Codes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: Obx(() {
                  return ListView.separated(
                    itemCount: _c.recentQrs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _c.recentQrs[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(item.colorValue).withValues(alpha: 0.15),
                          child: Icon(Icons.qr_code_2_rounded,
                              color: Color(item.colorValue), size: 20),
                        ),
                        title: Text(item.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(item.payload,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Colors.grey),
                        onTap: () {
                          Get.back();
                          _c.restoreRecent(item);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 6. VECTOR QR CANVAS PAINTER
// ════════════════════════════════════════════════════════════════════════════
class _QrCanvasPainter extends CustomPainter {
  final String data;
  final Color color;
  final IconData? centerIcon;

  _QrCanvasPainter({
    required this.data,
    required this.color,
    this.centerIcon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final bc = Barcode.qrCode();
      final elements = bc.make(
        data.isNotEmpty ? data : 'Sample',
        width: size.width,
        height: size.height,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final elem in elements) {
        if (elem is BarcodeBar && elem.black) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(elem.left, elem.top, elem.width, elem.height),
              const Radius.circular(1.0),
            ),
            paint,
          );
        }
      }

      // Draw Center Icon badge
      if (centerIcon != null) {
        final iconBoxSize = size.width * 0.22;
        final iconCenter = Offset(size.width / 2, size.height / 2);

        // Shield
        canvas.drawCircle(
          iconCenter,
          iconBoxSize / 2,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          iconCenter,
          iconBoxSize / 2,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(centerIcon!.codePoint),
            style: TextStyle(
              fontSize: iconBoxSize * 0.55,
              fontFamily: centerIcon!.fontFamily,
              package: centerIcon!.fontPackage,
              color: color,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(
          canvas,
          Offset(
            iconCenter.dx - (tp.width / 2),
            iconCenter.dy - (tp.height / 2),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  bool shouldRepaint(covariant _QrCanvasPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.centerIcon != centerIcon;
  }
}
