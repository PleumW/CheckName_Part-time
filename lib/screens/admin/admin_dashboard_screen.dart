import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/shift_provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/leave_request_model.dart';
import '../../providers/leave_request_provider.dart';
import 'schedule_management_screen.dart';
import 'admin_profile_screen.dart';
import '../../widgets/app_image_view.dart';
import '../../widgets/shift_detail_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_settings_sheet.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;
  late DateTime _selectedPayrollMonday = _getDefaultPayrollMonday();

  static DateTime _getDefaultPayrollMonday() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final currentMon = todayStart.subtract(Duration(days: now.weekday - 1));
    // Default to the previous week (Mon-Sun), which is due to be paid
    return currentMon.subtract(const Duration(days: 7));
  }

  static DateTime _getCurrentPayrollMonday() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return todayStart.subtract(Duration(days: now.weekday - 1));
  }

  DateTimeRange _getPreviousWeekRange([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final currentMon = todayStart.subtract(Duration(days: now.weekday - 1));
    final prevMon = currentMon.subtract(const Duration(days: 7));
    final prevSun = prevMon.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTimeRange(start: prevMon, end: prevSun);
  }

  DateTimeRange _getCurrentWeekRange([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final currentMon = todayStart.subtract(Duration(days: now.weekday - 1));
    return DateTimeRange(start: currentMon, end: now);
  }

  String _formatDateRange(DateTimeRange range) {
    final start = range.start;
    final end = range.end;
    return '${start.day}/${start.month}/${start.year + 543} - ${end.day}/${end.month}/${end.year + 543}';
  }

  String _formatDateSimple(DateTime d) {
    return '${d.day}/${d.month}/${d.year + 543}';
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'ระบบผู้ดูแล (Admin)';
      case 1:
        return 'จัดการตารางงาน';
      case 2:
        return 'จัดการข้อมูลพนักงาน';
      case 3:
        return 'สรุปยอดเงินต้องโอน (Payroll)';
      case 4:
        return 'โปรไฟล์ผู้ดูแลระบบ';
      default:
        return 'ระบบผู้ดูแล';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final leaveRequests = ref.watch(leaveRequestProvider);
    final shiftState = ref.watch(shiftProvider);
    final users = ref.watch(allUsersProvider).value ?? [];

    final activeShifts = shiftState.shifts.where((s) => s.status == 'in_progress').toList();
    final completedShifts = shiftState.shifts.where((s) => s.status == 'completed').toList();

    final screens = [
      _buildOverviewTab(context, activeShifts, completedShifts, notifications, leaveRequests, users),
      const ScheduleManagementScreen(),
      _buildEmployeeManagementTab(context, users, shiftState.shifts),
      _buildPayrollTab(context, users, completedShifts),
      const AdminProfileScreen(),
    ];

    if (_currentIndex == 1 || _currentIndex == 4) {
      // ScheduleManagementScreen and AdminProfileScreen provide their own Scaffold AppBar
      return Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.milk,
      appBar: AppBar(
        title: Text(_getAppBarTitle(_currentIndex)),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded),
                tooltip: 'การแจ้งเตือน',
                onPressed: () => _showNotificationsSheet(context, notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'การตั้งค่า (Settings)',
            onPressed: () => AppSettingsSheet.show(context),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.mocha,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'หน้าหลัก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_rounded),
          label: 'ตารางงาน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_rounded),
          label: 'พนักงาน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded),
          label: 'ระบบจ่ายเงิน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.badge_rounded),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }

  /// Tab 0: Overview - Leave requests, active working staff, & checkout reports ONLY
  Widget _buildOverviewTab(
    BuildContext context,
    List<ShiftModel> activeShifts,
    List<ShiftModel> completedShifts,
    List<AppNotificationModel> notifications,
    List<LeaveRequestModel> leaveRequests,
    List<UserModel> users,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary stats
          _buildAdminSummaryStats(activeShifts.length, completedShifts.length, notifications.length),
          const SizedBox(height: 20),

          // 1. Leave Requests Section (รายการแจ้งลางาน: ลากิจ & ลาด่วน)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.event_busy_rounded, size: 20, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'รายการแจ้งลางาน (Leave Requests)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              if (leaveRequests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${leaveRequests.length} รายการ',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (leaveRequests.isEmpty)
            Card(
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'ยังไม่มีรายการแจ้งลางานในขณะนี้',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ...leaveRequests.map((req) => _buildLeaveRequestCard(context, req)),

          const SizedBox(height: 24),

          // 2. Currently Working Section (พนักงานที่กำลังทำงานอยู่)
          Row(
            children: [
              const Icon(Icons.work_history_rounded, size: 20, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'พนักงานที่กำลังทำงาน (${activeShifts.length})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activeShifts.isEmpty)
            Card(
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'ไม่มีพนักงานที่กำลังปฏิบัติงานอยู่ในขณะนี้',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ...activeShifts.map((shift) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.shade200, width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => ShiftDetailSheet.show(context, shift),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              imageSource: users.where((u) => u.id == shift.userId).firstOrNull?.profileImage,
                              radius: 20,
                              backgroundColor: shift.storeColor.withValues(alpha: 0.15),
                              iconColor: shift.storeColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shift.userName.isNotEmpty ? shift.userName : 'ไม่ระบุชื่อพนักงาน',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: shift.storeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          shift.storeName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: shift.storeColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        shift.role,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PulsingStatusDot(size: 8, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text(
                                    'กำลังทำงาน',
                                    style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.milk,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 16, color: AppTheme.mocha),
                              const SizedBox(width: 6),
                              Text(
                                'กะ ${shift.startTime} - ${shift.endTime} น.',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                              ),
                              const Spacer(),
                              if (shift.checkInTime != null)
                                Text(
                                  'เข้างานจริง: ${_formatTime(shift.checkInTime!)} (${_formatElapsed(shift.checkInTime!)})',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                )
                              else
                                const Text(
                                  'เข้างานแล้ว',
                                  style: TextStyle(fontSize: 11, color: Colors.green),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // 3. Latest Checkout Reports Section (รายงานการส่งงานล่าสุด)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.photo_library_outlined, size: 20, color: AppTheme.mocha),
                  SizedBox(width: 8),
                  Text(
                    'รายงานการส่งงานล่าสุด (Check Out)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () => _showNotificationsSheet(context, notifications),
                  child: const Text('ดูทั้งหมด', style: TextStyle(color: AppTheme.mocha)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (notifications.isEmpty)
            Card(
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'ยังไม่มีรายงานการ Check Out ที่ส่งเข้ามา',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ...notifications.take(3).map((notif) => _buildCheckoutReportCard(context, notif)),
        ],
      ),
    );
  }

  /// Tab 2: Dedicated Employee Directory & Management
  Widget _buildEmployeeManagementTab(BuildContext context, List<UserModel> users, [List<ShiftModel>? allShifts]) {
    final prevWeekRange = _getPreviousWeekRange();
    final currentWeekRange = _getCurrentWeekRange();
    final shiftsList = allShifts ?? ref.watch(shiftProvider).shifts;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.people_alt_rounded, size: 22, color: AppTheme.mocha),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'จัดการข้อมูลพนักงานทั้งหมด',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.mocha.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'รวม ${users.length} คน',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.mocha, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (users.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.latte.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.mocha.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 40, color: AppTheme.mocha),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ไม่มีข้อมูลพนักงานในระบบ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'เมื่อพนักงานลงทะเบียนเข้าสู่ระบบ รายชื่อจะแสดงที่นี่โดยอัตโนมัติครับ ☕',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            ...users.map((userItem) {
              final isUserAdmin = userItem.role == 'admin';

              // Calculate user welfare
              final userWelfareShifts = shiftsList.where((s) {
                if (s.userId != userItem.id) return false;
                final hasAmount = s.welfareAmount != null && s.welfareAmount! > 0;
                final hasItems = s.welfareItems != null && s.welfareItems!.trim().isNotEmpty;
                return hasAmount || hasItems;
              }).toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              final currentWeekWelfare = userWelfareShifts.where((s) {
                final sDate = DateTime(s.date.year, s.date.month, s.date.day);
                return sDate.isAfter(currentWeekRange.start.subtract(const Duration(seconds: 1)));
              }).fold(0.0, (sum, s) => sum + (s.welfareAmount ?? 0.0));

              final prevWeekWelfare = userWelfareShifts.where((s) {
                final sDate = DateTime(s.date.year, s.date.month, s.date.day);
                return sDate.isAfter(prevWeekRange.start.subtract(const Duration(seconds: 1))) &&
                       sDate.isBefore(prevWeekRange.end);
              }).fold(0.0, (sum, s) => sum + (s.welfareAmount ?? 0.0));

              final totalWelfare = userWelfareShifts.fold(0.0, (sum, s) => sum + (s.welfareAmount ?? 0.0));

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.latte.withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Avatar + Name + Role Badge
                    Row(
                      children: [
                        UserAvatar(imageSource: userItem.profileImage, radius: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userItem.displayName.isNotEmpty
                                          ? '${userItem.displayName} (${userItem.fullName})'
                                          : userItem.email,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.textDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isUserAdmin
                                          ? Colors.purple.shade50
                                          : AppTheme.matcha.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isUserAdmin ? '👑 ผู้ดูแล' : '☕ พนักงาน',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isUserAdmin ? Colors.purple.shade700 : AppTheme.matcha,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      userItem.email,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bank Account Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.milk,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.latte.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 17, color: AppTheme.mocha),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'เลขบัญชี: ${userItem.bankAccount.isNotEmpty ? userItem.bankAccount : 'ยังไม่ได้ระบุ'}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                            ),
                          ),
                          if (userItem.bankAccount.isNotEmpty)
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.copy_rounded, size: 17, color: AppTheme.mocha),
                              tooltip: 'คัดลอกเลขบัญชี',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: userItem.bankAccount));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('คัดลอกเลขบัญชี ${userItem.bankAccount} ของ ${userItem.displayName} เรียบร้อยแล้ว! 📋'),
                                    backgroundColor: AppTheme.mocha,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Welfare Summary for this user
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_rounded, size: 16, color: AppTheme.mocha),
                              const SizedBox(width: 6),
                              const Text(
                                'สวัสดิการของพนักงาน',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mocha),
                              ),
                              const Spacer(),
                              Text(
                                '${userWelfareShifts.length} รายการ',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildWelfareStatChip(
                                label: 'สัปดาห์นี้',
                                amount: currentWeekWelfare,
                                color: Colors.green.shade700,
                                bgColor: Colors.green.shade50,
                              ),
                              _buildWelfareStatChip(
                                label: 'สัปดาห์ก่อน',
                                amount: prevWeekWelfare,
                                color: Colors.blueGrey.shade700,
                                bgColor: Colors.blueGrey.shade50,
                              ),
                              _buildWelfareStatChip(
                                label: 'รวมสะสม',
                                amount: totalWelfare,
                                color: AppTheme.mocha,
                                bgColor: AppTheme.latte.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showUserWelfareSheet(context, userItem, shiftsList),
                            icon: const Icon(Icons.coffee_rounded, size: 15),
                            label: const Text('จัดการสวัสดิการ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.mocha,
                              side: BorderSide(color: AppTheme.mocha.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditUserDialog(context, userItem),
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: const Text('แก้ไขข้อมูล', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textDark,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _showDeleteUserConfirmation(context, userItem),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('ลบพนักงาน (ลาออก)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, UserModel user) {
    final nicknameController = TextEditingController(text: user.nickname);
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final emailController = TextEditingController(text: user.email);
    final bankAccountController = TextEditingController(text: user.bankAccount);
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.edit_note_rounded, color: AppTheme.mocha, size: 24),
                  SizedBox(width: 8),
                  Text('แก้ไขข้อมูลพนักงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nicknameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อเล่น (Nickname)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstNameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อจริง (First Name)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      decoration: InputDecoration(
                        labelText: 'นามสกุล (Last Name)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: 'อีเมล (Email)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankAccountController,
                      decoration: InputDecoration(
                        labelText: 'เลขบัญชีธนาคาร & ชื่อธนาคาร',
                        hintText: 'เช่น กสิกรไทย 123-4-56789-0',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('ตำแหน่ง / บทบาท:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('พนักงาน (Staff)'),
                          selected: selectedRole == 'user',
                          selectedColor: AppTheme.latte,
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedRole = 'user');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('ผู้ดูแล (Admin)'),
                          selected: selectedRole == 'admin',
                          selectedColor: Colors.purple.shade100,
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedRole = 'admin');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final updatedUser = user.copyWith(
                      nickname: nicknameController.text.trim(),
                      firstName: firstNameController.text.trim(),
                      lastName: lastNameController.text.trim(),
                      email: emailController.text.trim(),
                      bankAccount: bankAccountController.text.trim(),
                      role: selectedRole,
                    );

                    firestoreService.saveUser(updatedUser);
                    Navigator.of(ctx).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('อัปเดตข้อมูลพนักงาน ${updatedUser.displayName} เรียบร้อยแล้ว! ✏️'),
                        backgroundColor: AppTheme.mocha,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('บันทึกการแก้ไข', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mocha,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteUserConfirmation(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Text('ยืนยันการลบพนักงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'คุณต้องการลบข้อมูลของ "${user.displayName} (${user.fullName})"\nออกจากระบบใช่หรือไม่?\n\n⚠️ ใช้สำหรับกรณีพนักงานลาออก หรือพ้นสภาพพนักงาน',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              firestoreService.deleteUser(user.id);
              Navigator.of(ctx).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบข้อมูลพนักงาน ${user.displayName} ออกจากระบบเรียบร้อยแล้ว'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.person_remove_rounded, size: 18),
            label: const Text('ยืนยันลบพนักงาน', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ================= User Welfare Management Methods =================

  Widget _buildWelfareStatChip({
    required String label,
    required double amount,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            '฿${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _showUserWelfareSheet(BuildContext context, UserModel user, List<ShiftModel> allShifts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _UserWelfareSheetContent(
          user: user,
          prevWeekRange: _getPreviousWeekRange(),
          currentWeekRange: _getCurrentWeekRange(),
          formatDateRange: _formatDateRange,
          onAddWelfare: () => _showAddWelfareDialog(context, user),
          onEditWelfare: (shift) => _showEditWelfareDialog(context, shift),
          onDeleteWelfare: (shift) => _confirmDeleteWelfare(context, shift),
        );
      },
    );
  }

  void _showAddWelfareDialog(BuildContext context, UserModel user) {
    final itemsController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedStore = 'Tokio Cat Cafe';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline_rounded, color: AppTheme.mocha, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'บันทึกสวัสดิการพนักงาน',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'พนักงาน: ${user.displayName.isNotEmpty ? user.displayName : user.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.mocha),
                    ),
                    const SizedBox(height: 14),

                    // Date Picker Tile
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 90)),
                          lastDate: DateTime.now().add(const Duration(days: 7)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.mocha),
                            const SizedBox(width: 8),
                            Text(
                              'วันที่: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year + 543}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Store Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedStore,
                      decoration: InputDecoration(
                        labelText: 'เลือกร้าน/สาขา',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.storefront_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Tokio Cat Cafe', child: Text('Tokio Cat Cafe')),
                        DropdownMenuItem(value: 'Kita Tea Bar', child: Text('Kita Tea Bar')),
                        DropdownMenuItem(value: 'Freshly Bakery', child: Text('Freshly Bakery')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStore = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Items TextField
                    TextField(
                      controller: itemsController,
                      decoration: InputDecoration(
                        labelText: 'รายการสวัสดิการ (อาหาร/เครื่องดื่ม)',
                        hintText: 'เช่น ชาเขียวมัทฉะ 1 แก้ว, ครัวซองต์ 1 ชิ้น',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.fastfood_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount TextField
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'จำนวนเงินสวัสดิการ (บาท)',
                        hintText: '0.00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.payments_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note TextField
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'หมายเหตุเพิ่มเติม (ถ้ามี)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final items = itemsController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (items.isEmpty && amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณาระบุรายการอาหารหรือยอดเงินสวัสดิการ')),
                      );
                      return;
                    }

                    final newShift = ShiftModel(
                      id: 'welfare-${DateTime.now().millisecondsSinceEpoch}',
                      userId: user.id,
                      userName: user.displayName.isNotEmpty ? user.displayName : user.fullName,
                      storeName: selectedStore,
                      date: selectedDate,
                      startTime: '12:00',
                      endTime: '12:00',
                      role: 'สวัสดิการพนักงาน',
                      branchLocation: selectedStore,
                      status: 'completed',
                      welfareItems: items.isNotEmpty ? items : 'สวัสดิการอาหาร/เครื่องดื่ม',
                      welfareAmount: amount,
                      note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : 'บันทึกสวัสดิการโดยผู้ดูแล',
                      checkInTime: selectedDate,
                      checkOutTime: selectedDate,
                    );

                    ref.read(shiftProvider.notifier).addShift(newShift);
                    Navigator.of(ctx).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('บันทึกสวัสดิการให้ ${user.displayName} เรียบร้อยแล้ว (฿${amount.toStringAsFixed(0)}) 🍵'),
                        backgroundColor: AppTheme.mocha,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('บันทึกสวัสดิการ', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mocha,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditWelfareDialog(BuildContext context, ShiftModel shift) {
    final itemsController = TextEditingController(text: shift.welfareItems ?? '');
    final amountController = TextEditingController(text: shift.welfareAmount?.toStringAsFixed(0) ?? '0');
    final noteController = TextEditingController(text: shift.note ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: AppTheme.mocha, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('แก้ไขรายการสวัสดิการ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ร้าน: ${shift.storeName} (${shift.date.day}/${shift.date.month}/${shift.date.year + 543})',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: itemsController,
                  decoration: InputDecoration(
                    labelText: 'รายการสวัสดิการ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.fastfood_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'จำนวนเงินสวัสดิการ (บาท)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'หมายเหตุ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                final items = itemsController.text.trim();

                final updated = shift.copyWith(
                  welfareItems: items.isNotEmpty ? items : null,
                  welfareAmount: amount,
                  note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : shift.note,
                );

                ref.read(shiftProvider.notifier).updateShift(updated);
                Navigator.of(ctx).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('อัปเดตข้อมูลสวัสดิการเรียบร้อยแล้ว! 🍵'),
                    backgroundColor: AppTheme.mocha,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('บันทึกการแก้ไข', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mocha,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteWelfare(BuildContext context, ShiftModel shift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('ลบรายการสวัสดิการ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'ต้องการลบรายการสวัสดิการ "${shift.welfareItems ?? 'รายการนี้'}" (฿${(shift.welfareAmount ?? 0).toStringAsFixed(0)}) ออกจากระบบใช่หรือไม่?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (shift.id.startsWith('welfare-')) {
                ref.read(shiftProvider.notifier).deleteShift(shift.id);
              } else {
                ref.read(shiftProvider.notifier).updateShift(
                  shift.copyWith(welfareItems: null, welfareAmount: 0.0),
                );
              }
              Navigator.of(ctx).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ลบรายการสวัสดิการเรียบร้อยแล้ว'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('ยืนยันลบ', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 3: Dedicated Payroll & Wednesday Payout System (Strict Mon - Sun Cutoff)
  Widget _buildPayrollTab(BuildContext context, List<UserModel> users, List<ShiftModel> completedShifts) {
    // Current cycle definition: Monday 00:00:00 to Sunday 23:59:59
    final cycleMon = DateTime(_selectedPayrollMonday.year, _selectedPayrollMonday.month, _selectedPayrollMonday.day);
    final cycleSun = cycleMon.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    final payoutWed = cycleMon.add(const Duration(days: 9)); // The Wednesday following Sunday

    final isDefaultPrevCycle = _selectedPayrollMonday.year == _getDefaultPayrollMonday().year &&
        _selectedPayrollMonday.month == _getDefaultPayrollMonday().month &&
        _selectedPayrollMonday.day == _getDefaultPayrollMonday().day;

    final isCurrentWeekCycle = _selectedPayrollMonday.year == _getCurrentPayrollMonday().year &&
        _selectedPayrollMonday.month == _getCurrentPayrollMonday().month &&
        _selectedPayrollMonday.day == _getCurrentPayrollMonday().day;

    // Filter shifts: ONLY completed shifts strictly within cycleMon and cycleSun
    // Next week's shifts or any date after cycleSun are NEVER included!
    List<ShiftModel> getFilteredShiftsForUser(String userId) {
      return completedShifts.where((s) {
        if (s.userId != userId) return false;
        final sDate = DateTime(s.date.year, s.date.month, s.date.day);
        return !sDate.isBefore(cycleMon) && !sDate.isAfter(cycleSun);
      }).toList();
    }

    // Calculate totals across all employees for this cycle
    double totalPayrollToTransfer = 0;
    int staffWithShiftsCount = 0;
    double totalHoursWorked = 0;

    for (final u in users) {
      final uShifts = getFilteredShiftsForUser(u.id);
      if (uShifts.isNotEmpty) {
        staffWithShiftsCount++;
        totalPayrollToTransfer += uShifts.fold(0.0, (sum, s) => sum + s.calculatedEarnings);
        totalHoursWorked += uShifts.fold(0.0, (sum, s) => sum + s.durationHours);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cycle Navigation Bar (< Mon - Sun >)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.latte),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.mocha, size: 28),
                      tooltip: 'รอบสัปดาห์ก่อนหน้า',
                      onPressed: () {
                        setState(() {
                          _selectedPayrollMonday = _selectedPayrollMonday.subtract(const Duration(days: 7));
                        });
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'รอบ: จันทร์ ${_formatDateSimple(cycleMon)} - อาทิตย์ ${_formatDateSimple(cycleSun)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.payments_outlined, size: 13, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'จ่ายวันพุธ ${_formatDateSimple(payoutWed)}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.mocha, size: 28),
                      tooltip: 'รอบสัปดาห์ถัดไป',
                      onPressed: () {
                        setState(() {
                          _selectedPayrollMonday = _selectedPayrollMonday.add(const Duration(days: 7));
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDefaultPrevCycle
                            ? null
                            : () => setState(() => _selectedPayrollMonday = _getDefaultPayrollMonday()),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isDefaultPrevCycle ? AppTheme.latte.withValues(alpha: 0.3) : Colors.transparent,
                          side: BorderSide(color: isDefaultPrevCycle ? AppTheme.mocha : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: Text(
                          'รอบจ่ายพุธนี้ (สัปดาห์ก่อน)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isDefaultPrevCycle ? FontWeight.bold : FontWeight.normal,
                            color: isDefaultPrevCycle ? AppTheme.mocha : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isCurrentWeekCycle
                            ? null
                            : () => setState(() => _selectedPayrollMonday = _getCurrentPayrollMonday()),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isCurrentWeekCycle ? AppTheme.latte.withValues(alpha: 0.3) : Colors.transparent,
                          side: BorderSide(color: isCurrentWeekCycle ? AppTheme.mocha : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: Text(
                          'รอบสัปดาห์นี้ (สะสม)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrentWeekCycle ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentWeekCycle ? AppTheme.mocha : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Total Payout KPI Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.mocha, AppTheme.mocha.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ยอดเงินรวมที่ต้องโอนทั้งหมดในรอบนี้',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        '฿${totalPayrollToTransfer.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'มีกะงาน $staffWithShiftsCount คน',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'รวม ${totalHoursWorked.toStringAsFixed(1)} ชม.',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: const [
              Icon(Icons.account_balance_wallet_rounded, size: 20, color: AppTheme.mocha),
              SizedBox(width: 8),
              Text(
                'สรุปยอดเงินต้องจ่ายพนักงาน (Payroll)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (users.isEmpty)
            Card(
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('ไม่มีข้อมูลพนักงานในระบบ', style: TextStyle(color: Colors.grey)),
                ),
              ),
            )
          else
            ...users.map((userItem) {
              final userCycleShifts = getFilteredShiftsForUser(userItem.id);
              final userHours = userCycleShifts.fold(0.0, (sum, s) => sum + s.durationHours);
              final userEarnings = userCycleShifts.fold(0.0, (sum, s) => sum + s.calculatedEarnings);

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: userEarnings > 0 ? Colors.green.shade200 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          UserAvatar(imageSource: userItem.profileImage, radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userItem.displayName.isNotEmpty
                                      ? '${userItem.displayName} (${userItem.fullName})'
                                      : userItem.email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'เข้างานสำเร็จ ${userCycleShifts.length} กะ • รวม ${userHours.toStringAsFixed(1)} ชม.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: userEarnings > 0 ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: userEarnings > 0 ? Colors.green.shade300 : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'ยอดที่ต้องโอน',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: userEarnings > 0 ? Colors.green.shade800 : Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '฿${userEarnings.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: userEarnings > 0 ? Colors.green.shade700 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bank Account Display with Copy Action
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.latte.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.latte),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 18, color: AppTheme.mocha),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'เลขบัญชี: ${userItem.bankAccount.isNotEmpty ? userItem.bankAccount : 'ยังไม่ได้ระบุ'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            if (userItem.bankAccount.isNotEmpty)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: userItem.bankAccount));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('คัดลอกเลขบัญชี ${userItem.bankAccount} ของ ${userItem.displayName} เรียบร้อยแล้ว! 📋'),
                                      backgroundColor: AppTheme.mocha,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.mocha),
                                label: const Text(
                                  'คัดลอก',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.mocha),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Completed Shift breakdown for this cycle
                      if (userCycleShifts.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    'รายการกะงานในรอบนี้ (${userCycleShifts.length} กะ):',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...userCycleShifts.map((s) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '• ${_formatDateSimple(s.date)} (${s.startTime} - ${s.endTime})',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                    ),
                                    Text(
                                      '${s.durationHours.toStringAsFixed(1)} ชม. = ฿${s.calculatedEarnings.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                                    ),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminSummaryStats(int activeCount, int completedCount, int reportCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('กำลังทำงาน', '$activeCount คน', Colors.orange.shade800),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          _buildStatColumn('ส่งงานแล้ว', '$completedCount กะ', Colors.green.shade700),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          _buildStatColumn('รายงานใหม่', '$reportCount รายการ', AppTheme.mocha),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildLeaveRequestCard(BuildContext context, LeaveRequestModel req) {
    final isUrgent = req.isUrgent;
    final dateStr = '${req.date.day}/${req.date.month}/${req.date.year + 543}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isUrgent ? Colors.red.shade300 : Colors.grey.shade300,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isUrgent ? Colors.red.shade100 : Colors.blue.shade100,
                      child: Icon(
                        isUrgent ? Icons.warning_amber_rounded : Icons.event_note_rounded,
                        size: 16,
                        color: isUrgent ? Colors.red.shade800 : Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      req.leaveTypeThai,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isUrgent ? Colors.red.shade800 : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isUrgent ? Colors.red.shade200 : Colors.blue.shade200),
                  ),
                  child: Text(
                    isUrgent ? 'ด่วนพิเศษ' : 'ตามขั้นตอน',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUrgent ? Colors.red.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('พนักงาน: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                Text(req.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('ร้าน / วันที่ลา: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                Text('${req.storeName} • $dateStr', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red.shade50.withValues(alpha: 0.5) : AppTheme.milk,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isUrgent ? Colors.red.shade100 : AppTheme.latte),
              ),
              child: Text(
                'เหตุผล: ${req.reason}',
                style: TextStyle(fontSize: 12, color: isUrgent ? Colors.red.shade900 : AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _confirmActionLeaveRequest(context, req, false),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _confirmActionLeaveRequest(context, req, true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('อนุมัติการลา', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmActionLeaveRequest(BuildContext context, LeaveRequestModel req, bool isApprove) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'อนุมัติการลา' : 'ปฏิเสธการลา'),
        content: Text('คุณต้องการ${isApprove ? "อนุมัติ" : "ปฏิเสธ"}คำขอลากิจ/ลาด่วนของ ${req.employeeName} วันที่ ${req.date.day}/${req.date.month}/${req.date.year + 543} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(leaveRequestProvider.notifier).deleteLeaveRequest(req.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${isApprove ? "อนุมัติ" : "ปฏิเสธ"}คำขอลางานของ ${req.employeeName} เรียบร้อยแล้ว'),
                  backgroundColor: isApprove ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? Colors.green : Colors.red),
            child: Text(isApprove ? 'ยืนยันอนุมัติ' : 'ยืนยันปฏิเสธ', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutReportCard(BuildContext context, AppNotificationModel notif) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notif.employeeName.isNotEmpty ? notif.employeeName : 'พนักงาน',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                  ),
                ),
                Text(
                  _formatTimeAgo(notif.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${notif.storeName} • ส่งงานสำเร็จแล้ว',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),

            if (notif.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.milk,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.latte),
                ),
                child: Text(
                  'หมายเหตุ: ${notif.note}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                ),
              ),
            ],

            if (notif.photos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: notif.photos.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final photoPath = notif.photos[idx];
                    return AppImageView(
                      imageSource: photoPath,
                      width: 70,
                      height: 70,
                      borderRadius: BorderRadius.circular(10),
                      enableFullScreenOnTap: true,
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDeleteReport(context, notif),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                  label: const Text('ลบรายงาน', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context, List<AppNotificationModel> notifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('การแจ้งเตือนทั้งหมด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(notificationProvider.notifier).markAllAsRead();
                        Navigator.pop(ctx);
                      },
                      child: const Text('อ่านทั้งหมดแล้ว', style: TextStyle(color: AppTheme.mocha)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('ไม่มีการแจ้งเตือน', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, idx) {
                          final notif = notifications[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: notif.type == 'payment_slip' ? Colors.green.shade100 : AppTheme.mocha.withValues(alpha: 0.15),
                                child: Icon(
                                  notif.type == 'payment_slip' ? Icons.verified_rounded : Icons.notifications_active,
                                  color: notif.type == 'payment_slip' ? Colors.green.shade800 : AppTheme.mocha,
                                  size: 20,
                                ),
                              ),
                              title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${notif.body}\n${_formatTimeAgo(notif.timestamp)}', style: const TextStyle(fontSize: 12)),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                onPressed: () {
                                  ref.read(notificationProvider.notifier).deleteNotification(notif.id);
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteReport(BuildContext context, AppNotificationModel notif, {VoidCallback? onSuccess}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรายงาน Check Out'),
        content: Text('คุณต้องการลบรายงานของ "${notif.employeeName}" (${notif.storeName}) ออกจากฐานข้อมูลใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(notificationProvider.notifier).deleteNotification(notif.id);
              Navigator.of(ctx).pop();
              if (onSuccess != null) onSuccess();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ลบรายงาน Check Out ออกจากระบบเรียบร้อยแล้ว'),
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute น.';
  }

  String _formatElapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} นาที';
    }
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '$hours ชม. $mins นาที';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม. ที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }
}

class _UserWelfareSheetContent extends ConsumerStatefulWidget {
  final UserModel user;
  final DateTimeRange prevWeekRange;
  final DateTimeRange currentWeekRange;
  final String Function(DateTimeRange) formatDateRange;
  final VoidCallback onAddWelfare;
  final Function(ShiftModel) onEditWelfare;
  final Function(ShiftModel) onDeleteWelfare;

  const _UserWelfareSheetContent({
    required this.user,
    required this.prevWeekRange,
    required this.currentWeekRange,
    required this.formatDateRange,
    required this.onAddWelfare,
    required this.onEditWelfare,
    required this.onDeleteWelfare,
  });

  @override
  ConsumerState<_UserWelfareSheetContent> createState() => _UserWelfareSheetContentState();
}

class _UserWelfareSheetContentState extends ConsumerState<_UserWelfareSheetContent> {
  String _selectedCycle = 'current_week'; // 'current_week', 'prev_week', 'all'

  Widget _buildMetricCard({
    required String title,
    required String subTitle,
    required double amount,
    required int count,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count ครั้ง',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '฿${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subTitle,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String cycleKey, String label) {
    final isSelected = _selectedCycle == cycleKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCycle = cycleKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mocha : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allShifts = ref.watch(shiftProvider).shifts;

    // Filter welfare shifts for this specific user
    final userWelfareShifts = allShifts.where((s) {
      if (s.userId != widget.user.id) return false;
      final hasAmount = s.welfareAmount != null && s.welfareAmount! > 0;
      final hasItems = s.welfareItems != null && s.welfareItems!.trim().isNotEmpty;
      return hasAmount || hasItems;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Current week welfare
    final currentWeekShifts = userWelfareShifts.where((s) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      return sDate.isAfter(widget.currentWeekRange.start.subtract(const Duration(seconds: 1)));
    }).toList();
    final currentWeekTotal = currentWeekShifts.fold(0.0, (sum, s) => sum + (s.welfareAmount ?? 0.0));

    // Previous week welfare
    final prevWeekShifts = userWelfareShifts.where((s) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      return sDate.isAfter(widget.prevWeekRange.start.subtract(const Duration(seconds: 1))) &&
             sDate.isBefore(widget.prevWeekRange.end);
    }).toList();
    final prevWeekTotal = prevWeekShifts.fold(0.0, (sum, s) => sum + (s.welfareAmount ?? 0.0));

    // All time welfare
    final allTimeTotal = userWelfareShifts.fold(0.0, (sum, s) => sum + (s.welfareAmount ?? 0.0));

    // Selected list
    List<ShiftModel> displayedList;
    if (_selectedCycle == 'current_week') {
      displayedList = currentWeekShifts;
    } else if (_selectedCycle == 'prev_week') {
      displayedList = prevWeekShifts;
    } else {
      displayedList = userWelfareShifts;
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.milk,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                UserAvatar(imageSource: widget.user.profileImage, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สวัสดิการ: ${widget.user.displayName.isNotEmpty ? widget.user.displayName : widget.user.fullName}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'บันทึกรายการอาหาร/เครื่องดื่มรายสัปดาห์',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: widget.onAddWelfare,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('เพิ่มรายการ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mocha,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3 Highlight Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'สัปดาห์นี้',
                          subTitle: 'จันทร์-อาทิตย์',
                          amount: currentWeekTotal,
                          count: currentWeekShifts.length,
                          color: Colors.green.shade700,
                          bgColor: Colors.green.shade50,
                          borderColor: Colors.green.shade200,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'สัปดาห์ก่อน',
                          subTitle: widget.formatDateRange(widget.prevWeekRange),
                          amount: prevWeekTotal,
                          count: prevWeekShifts.length,
                          color: Colors.blueGrey.shade800,
                          bgColor: Colors.blueGrey.shade50,
                          borderColor: Colors.blueGrey.shade200,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'สะสมทั้งหมด',
                          subTitle: 'ทุกช่วงเวลา',
                          amount: allTimeTotal,
                          count: userWelfareShifts.length,
                          color: AppTheme.mocha,
                          bgColor: AppTheme.latte.withValues(alpha: 0.4),
                          borderColor: AppTheme.latte,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Filter Segmented Bar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.latte),
                    ),
                    child: Row(
                      children: [
                        _buildFilterTab('current_week', 'สัปดาห์นี้ (${currentWeekShifts.length})'),
                        _buildFilterTab('prev_week', 'สัปดาห์ที่แล้ว (${prevWeekShifts.length})'),
                        _buildFilterTab('all', 'ทั้งหมด (${userWelfareShifts.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'ประวัติการใช้สวัสดิการ (${displayedList.length} รายการ)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'รวม ฿${displayedList.fold(0.0, (s, item) => s + (item.welfareAmount ?? 0)).toStringAsFixed(0)} บาท',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.mocha),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (displayedList.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.coffee_rounded, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'ไม่มีประวัติสวัสดิการในรอบนี้',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...displayedList.map((shiftItem) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: shiftItem.storeBackgroundColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.fastfood_rounded, color: shiftItem.storeColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: shiftItem.storeBackgroundColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            shiftItem.storeName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: shiftItem.storeColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${shiftItem.date.day}/${shiftItem.date.month}/${shiftItem.date.year + 543}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '฿${(shiftItem.welfareAmount ?? 0).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.mocha,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      shiftItem.welfareItems ?? 'สวัสดิการพนักงาน',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    if (shiftItem.note != null && shiftItem.note!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'หมายเหตุ: ${shiftItem.note}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    widget.onEditWelfare(shiftItem);
                                  } else if (action == 'delete') {
                                    widget.onDeleteWelfare(shiftItem);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, size: 18, color: AppTheme.mocha),
                                        SizedBox(width: 8),
                                        Text('แก้ไขรายการ'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('ลบรายการ', style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
