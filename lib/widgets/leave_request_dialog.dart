import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shift_model.dart';
import '../models/leave_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_request_provider.dart';
import '../theme/app_theme.dart';

class LeaveRequestDialog extends ConsumerStatefulWidget {
  final ShiftModel shift;

  const LeaveRequestDialog({super.key, required this.shift});

  static Future<void> show(BuildContext context, ShiftModel shift) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LeaveRequestDialog(shift: shift),
    );
  }

  @override
  ConsumerState<LeaveRequestDialog> createState() => _LeaveRequestDialogState();
}

class _LeaveRequestDialogState extends ConsumerState<LeaveRequestDialog> {
  final _reasonController = TextEditingController();
  String _selectedType = 'personal'; // 'personal' (ลากิจ) or 'urgent' (ลาด่วน)
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาระบุเหตุผลการลางาน'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = ref.read(authProvider);
    final employeeName = currentUser != null && currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : 'พนักงาน';
    final userId = currentUser?.id ?? 'user-${DateTime.now().millisecondsSinceEpoch}';

    final request = LeaveRequestModel(
      id: 'leave-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      employeeName: employeeName,
      shiftId: widget.shift.id,
      storeName: widget.shift.storeName,
      date: widget.shift.date,
      leaveType: _selectedType,
      reason: reason,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    await ref.read(leaveRequestProvider.notifier).submitLeaveRequest(request);

    if (!mounted) return;
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
                'ส่งคำขอ${request.leaveTypeThai}เรียบร้อยแล้ว แจ้งเตือนถึง Admin แล้ว 🐾',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: _selectedType == 'urgent' ? Colors.orange.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isUrgent = _selectedType == 'urgent';

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
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? Colors.red.shade50
                        : AppTheme.mocha.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUrgent ? Icons.warning_amber_rounded : Icons.event_busy_rounded,
                    color: isUrgent ? Colors.red.shade700 : AppTheme.mocha,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ยื่นเรื่องขอลางาน',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '${widget.shift.storeName} • วันที่ ${widget.shift.date.day}/${widget.shift.date.month}/${widget.shift.date.year + 543}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Leave Type Selection
            const Text(
              'เลือกประเภทการลา *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // ลากิจ (Personal)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = 'personal'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedType == 'personal'
                            ? AppTheme.mocha.withValues(alpha: 0.12)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedType == 'personal'
                              ? AppTheme.mocha
                              : Colors.grey.shade300,
                          width: _selectedType == 'personal' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            color: _selectedType == 'personal' ? AppTheme.mocha : Colors.grey,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ลากิจ 📝',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _selectedType == 'personal'
                                  ? AppTheme.mocha
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ล่วงหน้า/ธุระส่วนตัว',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ลาด่วน (Urgent)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = 'urgent'),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedType == 'urgent'
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedType == 'urgent'
                              ? Colors.red.shade700
                              : Colors.grey.shade300,
                          width: _selectedType == 'urgent' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.notification_important_rounded,
                            color: _selectedType == 'urgent' ? Colors.red.shade700 : Colors.grey,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ลาด่วน 🚨',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: _selectedType == 'urgent'
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'กะทันหัน/ป่วย/ฉุกเฉิน',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Reason Textfield
            const Text(
              'เหตุผลการขอลางาน *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _selectedType == 'urgent'
                    ? 'เช่น มีไข้สูงกะทันหัน, อุบัติเหตุ, ป่วยฉุกเฉิน'
                    : 'เช่น ติดสอบ, มีธุระจำเป็นกับครอบครัว',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isUrgent ? Colors.red.shade700 : AppTheme.mocha,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.send_rounded, size: 18),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'ส่งคำขอ${isUrgent ? 'ลาด่วน' : 'ลากิจ'} ถึง Admin',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUrgent ? Colors.red.shade700 : AppTheme.mocha,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
