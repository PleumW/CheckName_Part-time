import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift_model.dart';
import '../providers/shift_provider.dart';
import '../theme/app_theme.dart';
import 'checkout_dialog.dart';
import 'leave_request_dialog.dart';
import 'app_image_view.dart';

class ShiftDetailSheet extends ConsumerWidget {
  final ShiftModel shift;

  const ShiftDetailSheet({super.key, required this.shift});

  static void show(BuildContext context, ShiftModel shift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShiftDetailSheet(shift: shift),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeColor = shift.storeColor;
    final dateStr = "${shift.date.day} ${_thaiMonthName(shift.date.month)} ${shift.date.year + 543}";
    final dayOfWeekThai = _thaiDayFullName(shift.date.weekday);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
            const SizedBox(height: 16),

            // Header: Store Name & Day
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: storeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: storeColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.storefront_rounded, color: storeColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.storeName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: storeColor,
                            ),
                      ),
                      Text(
                        '$dayOfWeekThai, $dateStr',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(shift.status),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'ลบกะงานออกจาก Database',
                  onPressed: () => _confirmDeleteShift(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Time & Duration Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.milk,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.latte),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(shift.isFlexibleStart ? Icons.school_rounded : Icons.access_time_filled, color: AppTheme.mocha, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'เวลาทำงาน',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              shift.isFlexibleStart
                                  ? '🎒 ${shift.startTime} - ${shift.endTime} น.'
                                  : '${shift.startTime} - ${shift.endTime} น.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.mocha.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${shift.durationHours.toStringAsFixed(shift.isFlexibleStart ? 1 : 0)} ชม.',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mocha,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (shift.isFlexibleStart) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.mocha.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.mocha.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.mocha, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shift.checkInTime != null
                            ? 'เข้างานจริงเวลา ${shift.checkInTime!.hour.toString().padLeft(2, '0')}:${shift.checkInTime!.minute.toString().padLeft(2, '0')} น. (คำนวณค่าจ้างตามเวลาจริง ไม่คิดค่าสาย)'
                            : 'กะหลังเลิกเรียน (ยืดหยุ่น): ถึงร้านแล้วให้กด Check In เพื่อเริ่มนับเวลาทำงานจริง (ไม่คิดค่าสาย ☕)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textDark, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (shift.userName.isNotEmpty) ...[
              _buildInfoRow(
                icon: Icons.person_outline,
                label: 'พนักงานที่ปฏิบัติงาน',
                value: shift.userName,
              ),
              const SizedBox(height: 12),
            ],

            // Role / Position
            _buildInfoRow(
              icon: Icons.work_outline,
              label: 'หน้าที่ / ตำแหน่ง',
              value: shift.role,
            ),

            if (shift.branchLocation.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Location
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'สถานที่ / สาขา',
                value: shift.branchLocation,
              ),
            ],

            if (shift.note != null && shift.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.assignment_outlined,
                label: 'รายละเอียดงาน',
                value: shift.note!,
              ),
            ],

            // Check In / Check Out actual timestamps if available
            if (shift.checkInTime != null || shift.checkOutTime != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (shift.checkInTime != null)
                      Column(
                        children: [
                          const Text('เวลาเข้างานจริง', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '${shift.checkInTime!.hour.toString().padLeft(2, '0')}:${shift.checkInTime!.minute.toString().padLeft(2, '0')} น.',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    if (shift.checkOutTime != null)
                      Column(
                        children: [
                          const Text('เวลาเลิกงานจริง', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '${shift.checkOutTime!.hour.toString().padLeft(2, '0')}:${shift.checkOutTime!.minute.toString().padLeft(2, '0')} น.',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            // If photos were attached during Check Out
            if (shift.checkOutPhotos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.photo_library, size: 16, color: AppTheme.mocha),
                  const SizedBox(width: 6),
                  Text(
                    'รูปถ่ายตอนส่งงาน (${shift.checkOutPhotos.length} รูป)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shift.checkOutPhotos.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final photoPath = shift.checkOutPhotos[idx];
                    return AppImageView(
                      imageSource: photoPath,
                      width: 80,
                      height: 80,
                      borderRadius: BorderRadius.circular(10),
                      enableFullScreenOnTap: true,
                    );
                  },
                ),
              ),
            ],

            // Check out note
            if (shift.checkOutNote != null && shift.checkOutNote!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildInfoRow(
                icon: Icons.notes_outlined,
                label: 'หมายเหตุตอนส่งงาน',
                value: shift.checkOutNote!,
              ),
            ],

            // Welfare details
            if ((shift.welfareItems != null && shift.welfareItems!.isNotEmpty) || shift.welfareAmount != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.latte.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.latte),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.restaurant_rounded, size: 16, color: AppTheme.mocha),
                        SizedBox(width: 6),
                        Text(
                          'สวัสดิการพนักงานประจำกะ',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    if (shift.welfareItems != null && shift.welfareItems!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'รายการ: ${shift.welfareItems}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                      ),
                    ],
                    if (shift.welfareAmount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'มูลค่ารวม: ฿${shift.welfareAmount!.toStringAsFixed(0)} บาท',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mocha),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Earnings & Rate Breakdown Card
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.monetization_on_rounded, size: 18, color: Colors.green),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'สรุปรายได้กะงานนี้ (40 บ./ชม.)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '฿${shift.calculatedEarnings.toStringAsFixed(0)} บาท',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• เวลาทำงานตามตาราง: ${shift.durationHours.toStringAsFixed(1)} ชม.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  if (shift.checkInTime != null)
                    Text(
                      shift.isLateMoreThan15Mins
                          ? '• ⚠️ เช็คอินสายเกิน 15 นาที (ชม.แรก ได้ 20 บาท)'
                          : '• ✅ เช็คอินตรงเวลา (สายไม่เกิน 15 นาที)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: shift.isLateMoreThan15Mins ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                    ),
                  if (shift.checkOutTime != null)
                    Text(
                      shift.isOvertimeMoreThan15Mins
                          ? '• 🔥 เช็คเอาต์เกิน 15 นาที (+20 บาท OT)'
                          : '• ✅ เช็คเอาต์ตามตารางงานปกติ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: shift.isOvertimeMoreThan15Mins ? Colors.deepOrange : Colors.grey.shade800,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: _buildShiftActionButton(context, ref, shift),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftActionButton(BuildContext context, WidgetRef ref, ShiftModel shift) {
    if (shift.status == 'in_progress') {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pop();
          CheckoutDialog.show(context, shift);
        },
        icon: const Icon(Icons.camera_alt, size: 18),
        label: const Text('Check Out (ส่งงาน)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
        ),
      );
    } else if (shift.status == 'completed') {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle, size: 18),
        label: const Text('งานเสร็จสิ้นแล้ว'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.grey.shade700,
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(shiftProvider.notifier).checkIn(shift.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เช็คอินกะงานที่ ${shift.storeName} สำเร็จ! กำลังปฏิบัติงาน 🐾'),
                    backgroundColor: AppTheme.mocha,
                  ),
                );
              },
              icon: const Icon(Icons.fingerprint, size: 18),
              label: const Text('Check In (GPS)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: shift.storeColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                LeaveRequestDialog.show(context, shift);
              },
              icon: const Icon(Icons.event_busy, size: 16, color: Colors.redAccent),
              label: const Text('ขอลางาน', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        text = 'เสร็จสิ้น';
        break;
      case 'in_progress':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        text = 'กำลังทำงาน 🟢';
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        text = 'นัดหมาย';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _thaiMonthName(int month) {
    const months = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return months[month];
  }

  String _thaiDayFullName(int weekday) {
    const days = ['', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์'];
    return days[weekday];
  }

  void _confirmDeleteShift(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบกะงานนี้'),
        content: Text('คุณต้องการลบกะงาน "${shift.storeName} - ${shift.role}" ออกจากฐานข้อมูล Database ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(shiftProvider.notifier).deleteShift(shift.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ลบกะงานออกจาก Database สำเร็จแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบข้อมูล', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
