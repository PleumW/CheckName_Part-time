import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/shift_model.dart';
import '../providers/shift_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'app_image_view.dart';

class CheckoutDialog extends ConsumerStatefulWidget {
  final ShiftModel shift;

  const CheckoutDialog({super.key, required this.shift});

  static Future<void> show(BuildContext context, ShiftModel shift) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CheckoutDialog(shift: shift),
    );
  }

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _noteController = TextEditingController();
  final _welfareItemsController = TextEditingController();
  final _welfareAmountController = TextEditingController();
  final List<String> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _welfareItemsController.dispose();
    _welfareAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedImages.add(base64String);
        });
      }
    } catch (e) {
      // Fallback for desktop/simulator where camera might be unavailable
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเข้าถึงกล้อง/คลังรูปภาพได้: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _submitCheckOut() {
    setState(() => _isSubmitting = true);

    final currentUser = ref.read(authProvider);
    String employeeName = widget.shift.userName;
    if (employeeName.isEmpty || employeeName == 'ไม่ระบุชื่อ') {
      if (currentUser != null) {
        if (currentUser.nickname.isNotEmpty) {
          employeeName = '${currentUser.fullName} (${currentUser.nickname})';
        } else if (currentUser.fullName.isNotEmpty) {
          employeeName = currentUser.fullName;
        }
      }
    }
    if (employeeName.isEmpty) {
      employeeName = 'พนักงาน';
    }

    final welfareText = _welfareItemsController.text.trim();
    final welfareAmountNum = double.tryParse(_welfareAmountController.text.trim());

    ref.read(shiftProvider.notifier).checkOut(
          widget.shift.id,
          photos: _selectedImages,
          note: _noteController.text.trim(),
          employeeName: employeeName,
          welfareItems: welfareText.isNotEmpty ? welfareText : null,
          welfareAmount: welfareAmountNum,
        );

    setState(() => _isSubmitting = false);

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Check Out เรียบร้อย! ส่งรูปและหมายเหตุถึง Admin แล้ว 🐾',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final storeColor = widget.shift.storeColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header: Title & Shift Store Info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: storeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: storeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check Out & ส่งรายงานสรุปงาน',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '${widget.shift.storeName} • ${widget.shift.startTime} - ${widget.shift.endTime} น.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Section 1: Attached Photos
            Row(
              children: [
                const Icon(Icons.photo_library, size: 18, color: AppTheme.mocha),
                const SizedBox(width: 6),
                const Text(
                  'แนบรูปถ่าย',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${_selectedImages.length} รูป)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Buttons: Camera & Gallery
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('ถ่ายรูป'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('เลือกจากคลัง'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textDark,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Photos Preview List
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final imgPath = _selectedImages[index];

                    return Stack(
                      children: [
                        AppImageView(
                          imageSource: imgPath,
                          width: 90,
                          height: 90,
                          borderRadius: BorderRadius.circular(12),
                          enableFullScreenOnTap: true,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            const SizedBox(height: 18),

            // Section 2: Employee Welfare / Perks
            Row(
              children: const [
                Icon(Icons.restaurant_menu_rounded, size: 18, color: AppTheme.mocha),
                SizedBox(width: 6),
                Text(
                  'สวัสดิการอาหาร / เครื่องดื่มประจำวัน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.latte.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.latte),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _welfareItemsController,
                    decoration: InputDecoration(
                      labelText: 'รายการที่รับประทาน / ทานสวัสดิการ',
                      hintText: 'เช่น ชาไทยเย็น 1 แก้ว, ครัวซองต์ 1 ชิ้น',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.fastfood_outlined, size: 18, color: AppTheme.mocha),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _welfareAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'จำนวนเงินสวัสดิการรวม (บาท)',
                      hintText: 'เช่น 120',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.attach_money_rounded, size: 18, color: AppTheme.mocha),
                      suffixText: 'บาท',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 3: Remarks / Notes
            Row(
              children: const [
                Icon(Icons.notes_rounded, size: 18, color: AppTheme.mocha),
                SizedBox(width: 6),
                Text(
                  'หมายเหตุ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'ใส่หมายเหตุหรือสรุปงาน (เช่น ทำความสะอาดเรียบร้อย, ปิดร้านและล็อคประตูแล้ว, ของหมด)...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                filled: true,
                fillColor: AppTheme.milk,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.mocha, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitCheckOut,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _isSubmitting ? 'กำลังบันทึก...' : 'ยืนยัน Check Out',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: storeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
