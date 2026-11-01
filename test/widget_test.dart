import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitatokiofrashy/models/shift_model.dart';
import 'package:kitatokiofrashy/providers/shift_provider.dart';
import 'package:kitatokiofrashy/providers/notification_provider.dart';
import 'package:kitatokiofrashy/screens/user/user_dashboard_screen.dart';
import 'package:kitatokiofrashy/screens/user/user_timetable_screen.dart';
import 'package:kitatokiofrashy/screens/user/user_profile_screen.dart';
import 'package:kitatokiofrashy/screens/admin/admin_dashboard_screen.dart';
import 'package:kitatokiofrashy/screens/register_screen.dart';
import 'package:kitatokiofrashy/screens/login_screen.dart';
import 'package:kitatokiofrashy/models/leave_request_model.dart';
import 'package:kitatokiofrashy/models/user_model.dart';
import 'package:kitatokiofrashy/providers/auth_provider.dart';
import 'package:kitatokiofrashy/widgets/leave_request_dialog.dart';
import 'package:kitatokiofrashy/screens/admin/schedule_management_screen.dart';
import 'package:kitatokiofrashy/models/notification_model.dart';
import 'package:kitatokiofrashy/widgets/app_image_view.dart';
import 'package:kitatokiofrashy/widgets/user_avatar.dart';
import 'package:kitatokiofrashy/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kitatokiofrashy/services/web_notification_service.dart';
import 'package:kitatokiofrashy/services/location_service.dart';
import 'package:kitatokiofrashy/widgets/timetable_grid_widget.dart';

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(UserModel initial) : super() {
    state = initial;
  }
}

void main() {
  test('ShiftModel calculates duration and store color correctly', () {
    final shift = ShiftModel(
      id: 'test-1',
      userId: 'user-1',
      storeName: 'Tokio Haus',
      date: DateTime(2026, 9, 7),
      startTime: '10:00',
      endTime: '18:30',
      role: 'Barista',
      branchLocation: 'Siam Square',
    );

    expect(shift.startHourDecimal, 10.0);
    expect(shift.endHourDecimal, 18.5);
    expect(shift.durationHours, 8.5);
    expect(shift.storeName, 'Tokio Haus');
  });

  test('Starts with empty shifts, adds real shift, then checks in & checks out', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final shiftNotifier = container.read(shiftProvider.notifier);

    // Initial state: ZERO mock shifts
    expect(container.read(shiftProvider).shifts, isEmpty);
    expect(container.read(notificationProvider), isEmpty);

    // Add a real shift
    final realShift = ShiftModel(
      id: 'real-shift-1',
      userId: 'user-1',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '10:00',
      endTime: '18:00',
      role: 'Barista',
      branchLocation: 'สาขาสยามสแควร์ วัน',
    );

    shiftNotifier.addShift(realShift);
    expect(container.read(shiftProvider).shifts.length, 1);

    // Perform Check In
    shiftNotifier.checkIn('real-shift-1');
    final shiftAfterCheckIn = container.read(shiftProvider).shifts.first;
    expect(shiftAfterCheckIn.status, 'in_progress');
    expect(shiftAfterCheckIn.checkInTime, isNotNull);

    // Perform Check Out with photos and note
    const testNote = 'ทำความสะอาดร้านเรียบร้อย ล็อคประตูแล้วครับ';
    final testPhotos = ['photo_1.jpg', 'photo_2.jpg'];
    shiftNotifier.checkOut(
      'real-shift-1',
      photos: testPhotos,
      note: testNote,
      employeeName: 'พนักงานสมชาย',
    );

    final shiftAfterCheckOut = container.read(shiftProvider).shifts.first;
    expect(shiftAfterCheckOut.status, 'completed');
    expect(shiftAfterCheckOut.checkOutTime, isNotNull);
    expect(shiftAfterCheckOut.checkOutNote, testNote);
    expect(shiftAfterCheckOut.checkOutPhotos.length, 2);

    // Verify Notification received by Admin
    final notifications = container.read(notificationProvider);
    expect(notifications.length, 1);
    expect(notifications.first.note, testNote);
    expect(notifications.first.employeeName, 'พนักงานสมชาย');
  });

  testWidgets('UserDashboardScreen renders without mock data and displays empty states', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UserDashboardScreen(),
        ),
      ),
    );

    // Verify greeting
    expect(find.text('สวัสดีครับ, คุณพนักงาน 🐾'), findsOneWidget);

    // Verify empty state for today's shift and upcoming shifts
    expect(find.text('วันนี้ไม่มีกะทำงาน'), findsOneWidget);
    expect(find.text('ยังไม่มีกะงานที่ได้รับมอบหมายในขณะนี้'), findsOneWidget);
    expect(find.text('กะงานเร็วๆ นี้'), findsOneWidget);
  });

  testWidgets('UserTimetableScreen renders timetable view correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UserTimetableScreen(),
        ),
      ),
    );

    // Verify AppBar title
    expect(find.text('ตารางเข้างาน (Timetable)'), findsOneWidget);

    // Verify Store filter chips
    expect(find.text('ทุกร้าน 🐾'), findsOneWidget);
    expect(find.text('Tokio Haus'), findsWidgets);
    expect(find.text('Kita Cafe'), findsWidgets);
    expect(find.text('Freshly House'), findsWidgets);

    // Verify Timetable header cell
    expect(find.text('วัน/เวลา'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen and ScheduleManagementScreen render correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    // Verify title and notification icon
    expect(find.text('ระบบผู้ดูแล (Admin)'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    expect(find.text('รายการแจ้งลางาน (Leave Requests)'), findsOneWidget);
    expect(find.text('ยังไม่มีรายการแจ้งลางานในขณะนี้'), findsOneWidget);
    expect(find.text('รายงานการส่งงานล่าสุด (Check Out)'), findsOneWidget);
    expect(find.text('ยังไม่มีรายงานการ Check Out ที่ส่งเข้ามา'), findsOneWidget);

    // Tap on schedule management tab in BottomNavigationBar
    await tester.tap(find.text('ตารางงาน'));
    await tester.pumpAndSettle();

    // Verify ScheduleManagementScreen opened in Tab 1
    expect(find.text('จัดการตารางงาน (Schedules)'), findsOneWidget);
    expect(find.text('ยังไม่มีการกำหนดกะงานในระบบ'), findsOneWidget);
  });

  testWidgets('RegisterScreen renders avatar picker and nickname field', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    expect(find.text('สมัครสมาชิก (Register)'), findsOneWidget);
    expect(find.text('เพิ่มรูปโปรไฟล์'), findsOneWidget);
    expect(find.text('ชื่อเล่น (Nickname)'), findsOneWidget);
    expect(find.text('ชื่อจริง (First Name) *'), findsOneWidget);
  });

  testWidgets('UserProfileScreen renders profile info and stats', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UserProfileScreen(),
        ),
      ),
    );

    expect(find.text('โปรไฟล์ของฉัน'), findsOneWidget);
    expect(find.text('ชื่อเล่น'), findsOneWidget);
    expect(find.text('อีเมล'), findsOneWidget);
    expect(find.text('สาขาประจำ'), findsNothing);
    expect(find.textContaining('ต้องการแก้ไขชื่อ หรือเลขที่บัญชีธนาคาร?'), findsNothing);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
  });

  test('LeaveRequestModel supports personal and urgent leave', () {
    final personalLeave = LeaveRequestModel(
      id: 'leave-1',
      userId: 'user-1',
      employeeName: 'น้องปลื้ม',
      shiftId: 'shift-1',
      storeName: 'Tokio Haus',
      date: DateTime(2026, 9, 8),
      leaveType: 'personal',
      reason: 'ติดสอบปลายภาค',
      createdAt: DateTime.now(),
    );

    expect(personalLeave.isUrgent, false);
    expect(personalLeave.leaveTypeThai, 'ลากิจ');

    final urgentLeave = personalLeave.copyWith(leaveType: 'urgent', reason: 'ป่วยกะทันหัน มีไข้สูง');
    expect(urgentLeave.isUrgent, true);
    expect(urgentLeave.leaveTypeThai, 'ลาด่วน');

    final map = urgentLeave.toMap();
    expect(map['leaveType'], 'urgent');
    expect(map['reason'], 'ป่วยกะทันหัน มีไข้สูง');

    final parsed = LeaveRequestModel.fromMap(map, 'leave-2');
    expect(parsed.isUrgent, true);
    expect(parsed.employeeName, 'น้องปลื้ม');
  });

  testWidgets('LeaveRequestDialog renders personal and urgent options', (WidgetTester tester) async {
    final shift = ShiftModel(
      id: 'shift-test',
      userId: 'user-1',
      storeName: 'Tokio Haus',
      date: DateTime(2026, 9, 8),
      startTime: '10:00',
      endTime: '18:00',
      role: 'Barista',
      branchLocation: 'Siam Square',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LeaveRequestDialog(shift: shift),
          ),
        ),
      ),
    );

    expect(find.text('ยื่นเรื่องขอลางาน'), findsOneWidget);
    expect(find.text('ลากิจ 📝'), findsOneWidget);
    expect(find.text('ลาด่วน 🚨'), findsOneWidget);
    expect(find.text('เหตุผลการขอลางาน *'), findsOneWidget);
    expect(find.text('ส่งคำขอลากิจ ถึง Admin'), findsOneWidget);

    // Tap on urgent leave
    await tester.tap(find.text('ลาด่วน 🚨'));
    await tester.pumpAndSettle();

    expect(find.text('ส่งคำขอลาด่วน ถึง Admin'), findsOneWidget);
  });

  test('ShiftModel supports userName serialization and deserialization', () {
    final shift = ShiftModel(
      id: 'shift-user-test',
      userId: 'user-ton',
      userName: 'น้องต้น',
      storeName: 'Tokio Haus',
      date: DateTime(2026, 9, 8),
      startTime: '09:30',
      endTime: '17:45',
      role: 'Head Barista',
      branchLocation: '',
    );

    expect(shift.userName, 'น้องต้น');
    expect(shift.durationHours, 8.25);

    final map = shift.toMap();
    expect(map['userName'], 'น้องต้น');
    expect(map['userId'], 'user-ton');
    expect(map['branchLocation'], '');

    final deserialized = ShiftModel.fromMap(map, 'shift-user-test');
    expect(deserialized.userName, 'น้องต้น');
    expect(deserialized.startTime, '09:30');
    expect(deserialized.endTime, '17:45');
  });

  testWidgets('ScheduleManagementScreen renders timetable, user selector, custom time picker, clean store names, and removed branch', (WidgetTester tester) async {
    final testShift = ShiftModel(
      id: 'shift-admin-grid-1',
      userId: 'emp-123',
      userName: 'สมชาย ใจดี',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '10:00',
      endTime: '18:00',
      role: 'Barista',
      branchLocation: '',
    );

    final container = ProviderContainer();
    container.read(shiftProvider.notifier).addShift(testShift);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ScheduleManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Timetable view elements
    expect(find.text('จัดการตารางงาน (Schedules)'), findsOneWidget);
    expect(find.text('วัน/เวลา'), findsOneWidget); // Timetable header cell
    expect(find.text('ทุกร้าน'), findsOneWidget);
    expect(find.text('Tokio Haus'), findsWidgets);
    expect(find.text('Kita Cafe'), findsWidgets);
    expect(find.text('Freshly House'), findsWidgets);

    // Verify assigned employee name rendered in the timetable block
    expect(find.textContaining('สมชาย ใจดี'), findsWidgets);

    // Open Add Shift Dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify Add Shift Modal elements
    expect(find.text('กำหนดกะงานใหม่ (Add Shift)'), findsOneWidget);
    expect(find.text('เลือกพนักงานที่จัดตารางงาน'), findsOneWidget);
    expect(find.textContaining('เลือกร้าน'), findsWidgets);
    expect(find.text('เวลาทำงาน (ระบุเวลาเองได้)'), findsOneWidget);
    expect(find.text('เวลาเริ่มงาน'), findsOneWidget);
    expect(find.text('เวลาเลิกงาน'), findsOneWidget);

    // Verify Branch Location field is completely removed
    expect(find.text('สถานที่ / สาขา'), findsNothing);

    // Close dialog
    await tester.ensureVisible(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  });

  testWidgets('UserTimetableScreen separates my shifts from all users and allows viewing overall schedule', (WidgetTester tester) async {
    final userA = UserModel(
      id: 'user-a',
      firstName: 'สมใจ',
      lastName: 'รักงาน',
      nickname: 'น้องเอ',
      email: 'user_a@cafe.com',
      role: 'user',
      bankAccount: '111-222-3333',
    );

    final shiftA = ShiftModel(
      id: 'shift-a',
      userId: 'user-a',
      userName: 'น้องเอ',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '09:00',
      endTime: '15:00',
      role: 'Barista',
      branchLocation: '',
    );

    final shiftB = ShiftModel(
      id: 'shift-b',
      userId: 'user-b',
      userName: 'น้องบี',
      storeName: 'Kita Cafe',
      date: DateTime.now(),
      startTime: '12:00',
      endTime: '18:00',
      role: 'Cat Care',
      branchLocation: '',
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => AuthNotifier()..state = userA),
      ],
    );
    container.read(shiftProvider.notifier).addShift(shiftA);
    container.read(shiftProvider.notifier).addShift(shiftB);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: UserTimetableScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify scope buttons exist
    expect(find.text('กะงานของน้องเอ'), findsOneWidget);
    expect(find.text('ตารางโดยรวม (ทุกคน)'), findsOneWidget);

    // In personal mode (กะงานของฉัน): only shift A is in view, shift B is filtered out
    expect(find.textContaining('น้องเอ'), findsWidgets);
    expect(find.textContaining('น้องบี'), findsNothing);

    // Switch to overall schedule (ตารางโดยรวม)
    await tester.tap(find.text('ตารางโดยรวม (ทุกคน)'));
    await tester.pumpAndSettle();

    // In overall mode: both shift A and shift B are displayed
    expect(find.textContaining('น้องเอ'), findsWidgets);
    expect(find.textContaining('น้องบี'), findsWidgets);
    expect(find.text('โหมดแสดงผล'), findsOneWidget);
    expect(find.text('ตารางโดยรวม 🐾'), findsOneWidget);

    // Switch back to personal mode
    await tester.tap(find.text('กะงานของน้องเอ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('น้องบี'), findsNothing);
  });

  testWidgets('AdminDashboardScreen displays currently working staff with real employee name and check-in time, and opens ShiftDetailSheet on tap', (WidgetTester tester) async {
    final activeShift = ShiftModel(
      id: 'active-shift-101',
      userId: 'user-somchai',
      userName: 'คุณสมชาย ใจดี',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '08:00',
      endTime: '17:00',
      role: 'Head Barista',
      branchLocation: '',
      status: 'in_progress',
      checkInTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
    );

    final container = ProviderContainer();
    container.read(shiftProvider.notifier).addShift(activeShift);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify stats header
    expect(find.text('พนักงานที่กำลังทำงาน (1)'), findsOneWidget);
    expect(find.text('คุณสมชาย ใจดี'), findsOneWidget);
    expect(find.text('Head Barista'), findsOneWidget);
    expect(find.text('กำลังทำงาน'), findsWidgets);
    expect(find.textContaining('เข้างานจริง:'), findsOneWidget);

    // Tap active staff card
    await tester.tap(find.text('คุณสมชาย ใจดี'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify ShiftDetailSheet opened
    expect(find.text('พนักงานที่ปฏิบัติงาน'), findsOneWidget);
    expect(find.text('เวลาเข้างานจริง'), findsOneWidget);
    expect(find.text('Check Out (ส่งงาน)'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen displays checkout report, opens detail, and allows deletion', (WidgetTester tester) async {
    final notif = AppNotificationModel(
      id: 'notif-report-1',
      title: '🔔 พนักงานส่งงาน (Check Out) แล้ว',
      body: 'น้องปลื้ม เช็คเอาท์ที่ Kita Cafe แนบรูปถ่าย 1 รูป',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      shiftId: 'shift-99',
      storeName: 'Kita Cafe',
      employeeName: 'น้องปลื้ม',
      photos: ['data:image/jpeg;base64,/9j/4AAQSkZJRg=='],
      note: 'ทำความสะอาดเครื่องชงกาแฟและนับสต็อกเรียบร้อยค่ะ',
      isRead: false,
    );

    final container = ProviderContainer();
    container.read(notificationProvider.notifier).addCustomNotification(notif);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify report card rendered
    expect(find.text('น้องปลื้ม'), findsOneWidget);
    expect(find.textContaining('ทำความสะอาดเครื่องชงกาแฟ'), findsOneWidget);

    // Tap delete button directly on report card
    await tester.ensureVisible(find.text('ลบรายงาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบรายงาน'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('ลบรายงาน Check Out'), findsOneWidget);
    await tester.tap(find.text('ลบข้อมูล'));
    await tester.pumpAndSettle();

    // Report should be deleted from state
    expect(container.read(notificationProvider), isEmpty);
    expect(find.text('ยังไม่มีรายงานการ Check Out ที่ส่งเข้ามา'), findsOneWidget);
  });

  testWidgets('AppImageView safely handles empty or base64 data uri', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppImageView(imageSource: '', width: 50, height: 50),
              AppImageView(imageSource: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==', width: 50, height: 50),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Widget rendered with placeholder icons
    expect(find.byType(AppImageView), findsNWidgets(2));
  });

  testWidgets('ScheduleManagementScreen only allows editing and canceling shifts, prohibiting check-in and check-out', (WidgetTester tester) async {
    final container = ProviderContainer();
    final monday = container.read(shiftProvider).selectedWeekStart;
    final shift = ShiftModel(
      id: 'admin-sched-shift-1',
      userId: 'user-somchai',
      userName: 'คุณสมชาย ใจดี',
      storeName: 'Tokio Haus',
      date: monday,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Head Barista',
      branchLocation: '',
      status: 'upcoming',
    );

    container.read(shiftProvider.notifier).addShift(shift);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ScheduleManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on shift block in timetable grid
    await tester.tap(find.textContaining('คุณสมชาย ใจดี').first);
    await tester.pumpAndSettle();

    // Verify Admin Shift Manage sheet opened
    expect(find.text('แก้ไขตารางงาน'), findsOneWidget);
    expect(find.text('ยกเลิกกะงาน'), findsOneWidget);

    // Verify NO Check in, Check out, or Leave buttons exist
    expect(find.text('Check In (GPS)'), findsNothing);
    expect(find.text('Check Out (ส่งงาน)'), findsNothing);
    expect(find.text('ขอลางาน'), findsNothing);

    // Tap Edit
    await tester.tap(find.text('แก้ไขตารางงาน'));
    await tester.pumpAndSettle();

    // Verify Edit Shift Dialog opened
    expect(find.text('แก้ไขตารางงาน (Edit Shift)'), findsOneWidget);
    expect(find.text('บันทึกการแก้ไข'), findsOneWidget);

    // Save edit
    await tester.ensureVisible(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();

    // Re-open manage sheet and test Cancel (Delete)
    await tester.tap(find.textContaining('คุณสมชาย ใจดี').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยกเลิกกะงาน'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันยกเลิกกะงาน'), findsOneWidget);
    await tester.tap(find.text('ยืนยันยกเลิกกะงาน'));
    await tester.pumpAndSettle();

    // Shift should be deleted from schedule
    expect(container.read(shiftProvider).shifts, isEmpty);
    expect(find.text('ยังไม่มีการกำหนดกะงานในระบบ'), findsOneWidget);
  });

  test('AppTheme adopts a softer, lighter coffee tone while retaining coffee essence', () {
    expect(AppTheme.mocha, const Color(0xFF967259)); // Soft warm milk coffee / mocha
    expect(AppTheme.latte, const Color(0xFFF3ECE4)); // Soft creamy oat latte
    expect(AppTheme.milk, const Color(0xFFFAF7F2));  // Warm milk background
    expect(AppTheme.textDark, const Color(0xFF4A3B32)); // Deep espresso roast text
  });

  testWidgets('ScheduleManagementScreen displays UserAvatar in employee selection and preview cards', (WidgetTester tester) async {
    final user1 = UserModel(
      id: 'emp-001',
      firstName: 'กานต์',
      lastName: 'ใจเย็น',
      nickname: 'น้องกานต์',
      email: 'kan@cafe.com',
      role: 'user',
      bankAccount: '123-456-7890',
      profileImage: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );

    final container = ProviderContainer(
      overrides: [
        allUsersProvider.overrideWith((ref) => Stream.value([user1])),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ScheduleManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Add Shift Dialog
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Verify UserAvatar in employee selection preview card and dropdown
    expect(find.text('เลือกพนักงานที่จัดตารางงาน'), findsOneWidget);
    expect(find.byType(UserAvatar), findsWidgets);
    expect(find.textContaining('น้องกานต์'), findsWidgets);
  });

  test('ShiftModel and AppNotificationModel support welfare items and payment slip notification fields', () {
    final shift = ShiftModel(
      id: 's-welfare-1',
      userId: 'user-welfare-1',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '08:00',
      endTime: '16:00',
      role: 'Barista',
      branchLocation: '',
      welfareItems: 'อเมริกาโน่เย็น, ขนมปังปิ้ง',
      welfareAmount: 120.0,
    );

    expect(shift.welfareItems, 'อเมริกาโน่เย็น, ขนมปังปิ้ง');
    expect(shift.welfareAmount, 120.0);

    final notif = AppNotificationModel(
      id: 'notif-pay-1',
      title: 'แจ้งโอนเงินค่าจ้างแล้ว',
      body: 'โอนเงินค่าจ้าง 480 บาทเรียบร้อยแล้ว',
      timestamp: DateTime.now(),
      type: 'payment_slip',
      targetUserId: 'user-welfare-1',
      slipImage: 'data:image/png;base64,mockSlipData',
      amountPaid: 480.0,
      welfareItems: 'อเมริกาโน่เย็น, ขนมปังปิ้ง',
      welfareAmount: 120.0,
    );

    expect(notif.type, 'payment_slip');
    expect(notif.targetUserId, 'user-welfare-1');
    expect(notif.amountPaid, 480.0);
    expect(notif.slipImage, 'data:image/png;base64,mockSlipData');
    expect(notif.welfareItems, 'อเมริกาโน่เย็น, ขนมปังปิ้ง');
    expect(notif.welfareAmount, 120.0);
  });

  test('Check Out process records welfare items and welfare total amount', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final shiftNotifier = container.read(shiftProvider.notifier);

    final testShift = ShiftModel(
      id: 'shift-welfare-test',
      userId: 'user-001',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '09:00',
      endTime: '17:00',
      role: 'Barista',
      branchLocation: '',
      status: 'in_progress',
    );

    shiftNotifier.addShift(testShift);

    shiftNotifier.checkOut(
      'shift-welfare-test',
      photos: ['slip.png'],
      note: 'เลิกงานเรียบร้อย',
      employeeName: 'พนักงานสมชาย',
      welfareItems: 'ลาเต้ร้อน, ครัวซองต์',
      welfareAmount: 150.0,
    );

    final completedShift = container.read(shiftProvider).shifts.first;
    expect(completedShift.status, 'completed');
    expect(completedShift.welfareItems, 'ลาเต้ร้อน, ครัวซองต์');
    expect(completedShift.welfareAmount, 150.0);

    final notifs = container.read(notificationProvider);
    expect(notifs.length, 1);
    expect(notifs.first.welfareItems, 'ลาเต้ร้อน, ครัวซองต์');
    expect(notifs.first.welfareAmount, 150.0);
  });

  testWidgets('AdminDashboardScreen displays Payroll section with Bank Account & Payment Slip Modal', (WidgetTester tester) async {
    final testUser = UserModel(
      id: 'user-pay-1',
      firstName: 'สมชาย',
      lastName: 'สายกาแฟ',
      nickname: 'ชาย',
      email: 'somchai@cafe.com',
      role: 'user',
      bankAccount: 'กสิกรไทย 123-4-56789-0',
    );

    // Shift in previous week (Mon-Sun cycle)
    final shift = ShiftModel(
      id: 'shift-pay-1',
      userId: 'user-pay-1',
      storeName: 'Tokio Haus',
      date: DateTime.now().subtract(const Duration(days: 7)),
      startTime: '09:00',
      endTime: '17:00', // 8 hours = 320 THB
      role: 'Barista',
      branchLocation: '',
      status: 'completed',
    );

    // Shift in next week (must NOT be counted in the cut-off cycle)
    final nextWeekShift = ShiftModel(
      id: 'shift-pay-next-week',
      userId: 'user-pay-1',
      storeName: 'Kita Cafe',
      date: DateTime.now().add(const Duration(days: 5)),
      startTime: '09:00',
      endTime: '17:00', // 8 hours = 320 THB
      role: 'Barista',
      branchLocation: '',
      status: 'completed',
    );

    final container = ProviderContainer(
      overrides: [
        allUsersProvider.overrideWith((ref) => Stream.value([testUser])),
      ],
    );
    container.read(shiftProvider.notifier).addShift(shift);
    container.read(shiftProvider.notifier).addShift(nextWeekShift);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    // Switch to Payroll Tab (Tab 3)
    await tester.tap(find.text('ระบบจ่ายเงิน'));
    await tester.pumpAndSettle();

    // Verify Payroll & Payment section exists
    expect(find.text('สรุปยอดเงินต้องจ่ายพนักงาน (Payroll)'), findsOneWidget);
    expect(find.textContaining('ชาย'), findsWidgets);
    expect(find.textContaining('กสิกรไทย 123-4-56789-0'), findsOneWidget);

    // Verify the amount to transfer is ONLY ฿320 (and NOT ฿640 because next week shift is excluded)
    expect(find.text('฿320'), findsWidgets);
    expect(find.text('฿640'), findsNothing);

    // Verify "แจ้งโอนเงิน & แนบสลิป" button is REMOVED as requested
    expect(find.text('แจ้งโอนเงิน & แนบสลิป'), findsNothing);
    expect(find.text('คัดลอก'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen integrates Admin Profile screen in Tab 4 with badge and privileges', (WidgetTester tester) async {
    final adminUser = UserModel(
      id: 'adm-001',
      firstName: 'บอสใหญ่',
      lastName: 'ใจดี',
      nickname: 'บอส',
      email: 'boss@chcekname.com',
      role: 'admin',
      bankAccount: 'ไทยพาณิชย์ 999-8-77766-5',
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => AuthNotifier()..state = adminUser),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Admin Profile Tab (Tab 4)
    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();

    // Verify Administrator ID Badge
    expect(find.text('โปรไฟล์ผู้ดูแลระบบ'), findsOneWidget);
    expect(find.text('ChcekName'), findsWidgets);
    expect(find.text('ADMINISTRATOR BADGE • บัตรประจำตัวผู้ดูแลระบบ'), findsOneWidget);
    expect(find.text('● ACTIVE / ADMIN'), findsOneWidget);
    expect(find.textContaining('บอส'), findsWidgets);
    expect(find.textContaining('บอสใหญ่ ใจดี'), findsWidgets);
    expect(find.text('CN-ADM-ADM-00'), findsNothing); // Role & ID tag chips removed per user request

    // Verify that the requested elements are removed (Privileges box, Security ID, Barcode, etc.)
    expect(find.text('ขอบเขตสิทธิ์การดูแลระบบ (Admin Access)'), findsNothing);
    expect(find.text('ระดับสิทธิ์การใช้งาน'), findsNothing);
    expect(find.text('สังกัดระบบ'), findsNothing);
    expect(find.textContaining('SECURITY ID:'), findsNothing);
    expect(find.textContaining('ต้องการแก้ไขข้อมูลส่วนตัวหรือการแจ้งเตือน?'), findsNothing);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
  });

  test('AuthNotifier saves and restores session state via SharedPreferences', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final authNotifier = container.read(authProvider.notifier);

    // Sign in user
    await authNotifier.signIn(email: 'user@cafe.com', password: 'password123');
    expect(container.read(authProvider)?.email, 'user@cafe.com');

    // Re-create AuthNotifier to simulate app restart
    final container2 = ProviderContainer();
    addTearDown(container2.dispose);

    final restoredUser = await container2.read(authProvider.notifier).restoreSavedSession();
    expect(restoredUser, isNotNull);
    expect(restoredUser?.email, 'user@cafe.com');

    // Test sign out clears session
    await container2.read(authProvider.notifier).signOut();
    expect(container2.read(authProvider), isNull);

    final container3 = ProviderContainer();
    addTearDown(container3.dispose);
    final userAfterSignOut = await container3.read(authProvider.notifier).restoreSavedSession();
    expect(userAfterSignOut, isNull);
  });

  test('ShiftModel calculates wage at 40 THB/hr, late penalty (>15m), early check-in, and OT (+20 THB)', () {
    final shiftDate = DateTime(2026, 9, 7);

    // Scenario 1: Normal 8-hour shift, on-time check in & out -> 8 * 40 = 320 THB
    final normalShift = ShiftModel(
      id: 'shift-1',
      userId: 'u1',
      storeName: 'Tokio',
      date: shiftDate,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Staff',
      branchLocation: '',
      checkInTime: DateTime(2026, 9, 7, 10, 0),
      checkOutTime: DateTime(2026, 9, 7, 18, 0),
    );
    expect(normalShift.isLateMoreThan15Mins, false);
    expect(normalShift.isOvertimeMoreThan15Mins, false);
    expect(normalShift.calculatedEarnings, 320.0);

    // Scenario 2: Early check-in (09:45) -> Counted as standard schedule (320 THB)
    final earlyShift = ShiftModel(
      id: 'shift-2',
      userId: 'u1',
      storeName: 'Tokio',
      date: shiftDate,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Staff',
      branchLocation: '',
      checkInTime: DateTime(2026, 9, 7, 9, 45),
      checkOutTime: DateTime(2026, 9, 7, 18, 0),
    );
    expect(earlyShift.isLateMoreThan15Mins, false);
    expect(earlyShift.calculatedEarnings, 320.0);

    // Scenario 3: Check in 10 mins late (<= 15 mins) -> Grace period, 320 THB
    final graceShift = ShiftModel(
      id: 'shift-3',
      userId: 'u1',
      storeName: 'Tokio',
      date: shiftDate,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Staff',
      branchLocation: '',
      checkInTime: DateTime(2026, 9, 7, 10, 10),
      checkOutTime: DateTime(2026, 9, 7, 18, 0),
    );
    expect(graceShift.isLateMoreThan15Mins, false);
    expect(graceShift.calculatedEarnings, 320.0);

    // Scenario 4: Check in 25 mins late (> 15 mins) -> 1st hr = 20 THB, rest 7 hrs @ 40 THB = 300 THB
    final lateShift = ShiftModel(
      id: 'shift-4',
      userId: 'u1',
      storeName: 'Tokio',
      date: shiftDate,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Staff',
      branchLocation: '',
      checkInTime: DateTime(2026, 9, 7, 10, 25),
      checkOutTime: DateTime(2026, 9, 7, 18, 0),
    );
    expect(lateShift.isLateMoreThan15Mins, true);
    expect(lateShift.calculatedEarnings, 300.0); // (7 * 40) + 20 = 300 THB

    // Scenario 5: Check out 20 mins late (> 15 mins after end) -> OT bonus +20 THB -> 320 + 20 = 340 THB
    final otShift = ShiftModel(
      id: 'shift-5',
      userId: 'u1',
      storeName: 'Tokio',
      date: shiftDate,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Staff',
      branchLocation: '',
      checkInTime: DateTime(2026, 9, 7, 10, 0),
      checkOutTime: DateTime(2026, 9, 7, 18, 20),
    );
    expect(otShift.isOvertimeMoreThan15Mins, true);
    expect(otShift.calculatedEarnings, 340.0);
  });

  testWidgets('LoginScreen renders Forgot Password button and no Google Sign-In button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ลืมรหัสผ่าน?'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsNothing);

    // Tap Forgot Password button
    await tester.tap(find.text('ลืมรหัสผ่าน?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ลืมรหัสผ่าน'), findsWidgets);
    expect(find.text('ส่งลิงก์รีเซ็ต'), findsOneWidget);
  });

  testWidgets('Admin Employee Directory allows editing user name/bank account and deleting user on resignation', (WidgetTester tester) async {
    final emp = UserModel(
      id: 'emp-edit-1',
      firstName: 'สมศักดิ์',
      lastName: 'รักดี',
      nickname: 'ศักดิ์',
      email: 'somsak@kitatokio.com',
      role: 'user',
      bankAccount: 'กรุงไทย 111-2-33333-4',
    );

    final container = ProviderContainer(
      overrides: [
        allUsersProvider.overrideWith((ref) => Stream.value([emp])),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Employee Directory Tab (Tab 2)
    await tester.tap(find.text('พนักงาน'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ศักดิ์'), findsOneWidget);
    expect(find.textContaining('กรุงไทย 111-2-33333-4'), findsOneWidget);
    expect(find.text('แก้ไขข้อมูล'), findsOneWidget);
    expect(find.text('ลบพนักงาน (ลาออก)'), findsOneWidget);

    // Tap Edit Info
    await tester.tap(find.text('แก้ไขข้อมูล'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขข้อมูลพนักงาน'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'ชื่อเล่น (Nickname)'), 'พี่ศักดิ์');
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();

    // Tap Delete User
    await tester.tap(find.text('ลบพนักงาน (ลาออก)'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันการลบพนักงาน'), findsOneWidget);
    await tester.tap(find.text('ยืนยันลบพนักงาน'));
    await tester.pumpAndSettle();
  });

  test('WebNotificationService functions safely without error on non-web platforms', () {
    expect(() => WebNotificationService.requestPermission(), returnsNormally);
    expect(() => WebNotificationService.showNotification(title: 'Test', body: 'Message'), returnsNormally);
    expect(WebNotificationService.isSupported, isFalse);
  });

  testWidgets('Admin Employee Directory displays Welfare summary and opens User Welfare sheet', (WidgetTester tester) async {
    final emp = UserModel(
      id: 'emp-welfare-1',
      firstName: 'วรรณา',
      lastName: 'ใจเย็น',
      nickname: 'นา',
      email: 'wanna@kitatokio.com',
      role: 'user',
      bankAccount: 'กสิกรไทย 555-4-32100-9',
    );

    final today = DateTime.now();
    final welfareShift = ShiftModel(
      id: 'shift-welfare-1',
      userId: 'emp-welfare-1',
      userName: 'วรรณา (นา)',
      storeName: 'Tokio Cat Cafe',
      date: today,
      startTime: '10:00',
      endTime: '18:00',
      role: 'Barista',
      branchLocation: 'Siam',
      status: 'completed',
      welfareItems: 'มัทฉะลาเต้เย็น, แซนวิชแฮมชีส',
      welfareAmount: 140.0,
    );

    final container = ProviderContainer(
      overrides: [
        allUsersProvider.overrideWith((ref) => Stream.value([emp])),
      ],
    );
    container.read(shiftProvider.notifier).addShift(welfareShift);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Employee Directory Tab (Tab 2)
    await tester.tap(find.text('พนักงาน'));
    await tester.pumpAndSettle();

    expect(find.text('สวัสดิการของพนักงาน'), findsOneWidget);
    expect(find.text('สัปดาห์นี้'), findsOneWidget);
    expect(find.textContaining('฿140'), findsWidgets);
    expect(find.text('จัดการสวัสดิการ'), findsOneWidget);

    // Tap Manage Welfare
    await tester.tap(find.text('จัดการสวัสดิการ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('สวัสดิการ: นา'), findsOneWidget);
    expect(find.text('เพิ่มรายการ'), findsOneWidget);
    expect(find.textContaining('มัทฉะลาเต้เย็น, แซนวิชแฮมชีส'), findsOneWidget);

    // Tap Add Welfare button in modal
    await tester.tap(find.text('เพิ่มรายการ'));
    await tester.pumpAndSettle();

    expect(find.text('บันทึกสวัสดิการพนักงาน'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'รายการสวัสดิการ (อาหาร/เครื่องดื่ม)'), 'เค้กช็อกโกแลต 1 ชิ้น');
    await tester.enterText(find.widgetWithText(TextField, 'จำนวนเงินสวัสดิการ (บาท)'), '75');
    await tester.tap(find.text('บันทึกสวัสดิการ'));
    await tester.pumpAndSettle();

    // Verify added
    expect(find.textContaining('เค้กช็อกโกแลต 1 ชิ้น'), findsOneWidget);
    expect(find.text('฿75'), findsOneWidget);
  });

  testWidgets('Settings sheet contains Edit Profile, Notification, and Logout; ID Card renders without inline edit', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UserProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Employee ID Card branding
    expect(find.text('CHCEKNAME'), findsOneWidget);
    expect(find.text('STAFF IDENTIFICATION BADGE • บัตรประจำตัวพนักงาน'), findsOneWidget);
    expect(find.text('● ACTIVE'), findsOneWidget);
    expect(find.text('แก้ไขข้อมูล'), findsNothing); // Removed inline edit button as requested

    // Verify settings gear button exists
    expect(find.byIcon(Icons.settings_rounded), findsWidgets);

    // Tap Settings Gear Icon
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pumpAndSettle();

    // Verify Settings Sheet options
    expect(find.text('การตั้งค่า (Settings)'), findsOneWidget);
    expect(find.text('แก้ไขข้อมูลส่วนตัว'), findsOneWidget);
    expect(find.text('เปิดการแจ้งเตือน'), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsWidgets);
  });

  testWidgets('Schedule assignment triggers notification for user and displays in UserDashboardScreen with badge', (WidgetTester tester) async {
    final user = UserModel(
      id: 'emp-notif-1',
      firstName: 'สมชาย',
      lastName: 'ใจดี',
      nickname: 'ชาย',
      email: 'somchai@kitatokio.com',
      role: 'user',
      bankAccount: '123-4-56789-0',
    );

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final futureShift = ShiftModel(
      id: 'shift-new-1',
      userId: 'emp-notif-1',
      userName: 'ชาย',
      storeName: 'Tokio Cat Cafe',
      branchLocation: '',
      date: tomorrow,
      startTime: '09:00',
      endTime: '18:00',
      role: 'Barista',
      status: 'upcoming',
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
      ],
    );
    container.read(shiftProvider.notifier).addShift(futureShift);

    container.read(notificationProvider.notifier).sendShiftAssignedNotification(
      targetUserId: 'emp-notif-1',
      employeeName: 'ชาย',
      storeName: 'Tokio Cat Cafe',
      date: tomorrow,
      startTime: '09:00',
      endTime: '18:00',
      role: 'Barista',
      shiftId: futureShift.id,
    );

    final unread = container.read(userUnreadNotificationCountProvider('emp-notif-1'));
    expect(unread, equals(1));

    final shiftState = container.read(shiftProvider);
    final next = shiftState.nextUpcomingShiftForUser('emp-notif-1', nickname: 'ชาย');
    expect(next, isNotNull);
    expect(next?.storeName, equals('Tokio Cat Cafe'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: UserDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('กะงานถัดไปของคุณ'), findsOneWidget);
    expect(find.textContaining('Tokio Cat Cafe'), findsWidgets);

    await tester.tap(find.byIcon(Icons.notifications_rounded));
    await tester.pumpAndSettle();

    expect(find.text('การแจ้งเตือนของคุณ'), findsOneWidget);
    expect(find.textContaining('มีการจัดตารางงานใหม่ให้คุณ'), findsOneWidget);
  });

  testWidgets('Schedule nav icon displays red dot badge when new shift notification arrives and clears upon tap', (WidgetTester tester) async {
    final user = UserModel(
      id: 'emp-red-dot-1',
      firstName: 'มานะ',
      lastName: 'อดทน',
      nickname: 'นะ',
      email: 'mana@kitatokio.com',
      role: 'user',
      bankAccount: '111-2-33333-4',
    );

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final futureShift = ShiftModel(
      id: 'shift-red-dot-1',
      userId: 'emp-red-dot-1',
      userName: 'นะ',
      storeName: 'Tokio Cat Cafe',
      branchLocation: '',
      date: tomorrow,
      startTime: '10:00',
      endTime: '19:00',
      role: 'Barista',
      status: 'upcoming',
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
      ],
    );

    // Initial render: no shift notification, hasUnreadShiftNotificationProvider is false
    final initialHasShiftNotif = container.read(userHasUnreadShiftNotificationProvider('emp-red-dot-1'));
    expect(initialHasShiftNotif, isFalse);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: UserDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Nav item 'ตารางงาน' is present
    expect(find.text('ตารางงาน'), findsOneWidget);

    // Now Admin assigns a shift to this user
    container.read(shiftProvider.notifier).addShift(futureShift);
    container.read(notificationProvider.notifier).sendShiftAssignedNotification(
      targetUserId: 'emp-red-dot-1',
      employeeName: 'นะ',
      storeName: 'Tokio Cat Cafe',
      date: tomorrow,
      startTime: '10:00',
      endTime: '19:00',
      role: 'Barista',
      shiftId: futureShift.id,
    );

    await tester.pumpAndSettle();

    // Check userHasUnreadShiftNotificationProvider is now true
    final hasShiftNotif = container.read(userHasUnreadShiftNotificationProvider('emp-red-dot-1'));
    expect(hasShiftNotif, isTrue);

    // Tapping on 'ตารางงาน' (Nav Tab 1) should switch tab and clear unread shift notifications
    await tester.tap(find.text('ตารางงาน'));
    await tester.pumpAndSettle();

    // Verify notifications for shift are marked as read
    final afterTapShiftNotif = container.read(userHasUnreadShiftNotificationProvider('emp-red-dot-1'));
    expect(afterTapShiftNotif, isFalse);
  });

  testWidgets('Notification settings render Switch toggle and in-app heads up is removed', (WidgetTester tester) async {
    final user = UserModel(
      id: 'emp-switch-1',
      firstName: 'กานดา',
      lastName: 'ใจงาม',
      nickname: 'กานต์',
      email: 'karn@kitatokio.com',
      role: 'user',
      bankAccount: '222-3-44444-5',
    );

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) => _TestAuthNotifier(user)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: UserDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify settings gear button exists and tap it
    expect(find.byIcon(Icons.settings_rounded), findsWidgets);
    await tester.tap(find.byIcon(Icons.settings_rounded).first);
    await tester.pumpAndSettle();

    // Verify Notification setting tile has a Switch widget instead of ElevatedButton
    expect(find.text('เปิดการแจ้งเตือน'), findsOneWidget);
    expect(find.byType(Switch), findsWidgets);

    // Close settings sheet
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // Verify no in-app heads-up banner exists
    expect(find.text('เปิดดู'), findsNothing);
  });

  test('ShiftModel supports flexible after-class shift ("เลิกเรียนไวที่สุด - 21:30") with zero late penalty and actual check-in duration wage', () {
    final shiftDate = DateTime(2026, 9, 7);

    // Scenario: Flexible start shift ("เลิกเรียนไวที่สุด" to "21:30")
    // Employee arrives and checks in at 16:30, checks out at 21:30 (5 hours)
    final flexShift = ShiftModel(
      id: 'flex-shift-1',
      userId: 'u1',
      storeName: 'Tokio Haus',
      date: shiftDate,
      startTime: 'เลิกเรียนไวที่สุด',
      endTime: '21:30',
      role: 'Staff (หลังเลิกเรียน)',
      branchLocation: '',
      checkInTime: DateTime(2026, 9, 7, 16, 30),
      checkOutTime: DateTime(2026, 9, 7, 21, 30),
    );

    expect(flexShift.isFlexibleStart, true);
    expect(flexShift.isLateMoreThan15Mins, false); // No late penalty
    expect(flexShift.durationHours, 5.0);
    expect(flexShift.calculatedEarnings, 200.0); // 5 hours * 40 THB = 200 THB

    // Even if employee arrives later at 17:15, flexible shift is never late
    final flexShiftLateArrival = flexShift.copyWith(
      checkInTime: DateTime(2026, 9, 7, 17, 15),
      checkOutTime: DateTime(2026, 9, 7, 21, 30),
    );
    expect(flexShiftLateArrival.isFlexibleStart, true);
    expect(flexShiftLateArrival.isLateMoreThan15Mins, false);
    // 17:15 to 21:30 = 4.25 hours
    expect(flexShiftLateArrival.durationHours, 4.25);
    expect(flexShiftLateArrival.calculatedEarnings, 4.25 * 40.0);
  });

  testWidgets('ScheduleManagementScreen renders flexible shift toggle and preset chip', (WidgetTester tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ScheduleManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Add Shift button
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    // Verify quick preset chips are removed per user request
    expect(find.text('แม่แบบกะงานด่วน:'), findsNothing);
    expect(find.text('🎒 เลิกเรียนไวสุด - 21:30 น.'), findsNothing);

    // Verify flexible start switch title exists
    expect(find.text('กะหลังเลิกเรียน (เลิกเรียนไวที่สุด)'), findsOneWidget);

    // Toggle the flexible switch
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Verify start time now shows flexible indicator
    expect(find.text('เลิกเรียนไวที่สุด 🎒'), findsOneWidget);

    // Close modal
    await tester.ensureVisible(find.text('บันทึกกะงาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกกะงาน'));
    await tester.pumpAndSettle();
  });

  testWidgets('ScheduleManagementScreen allows selecting multiple stores when adding shifts', (WidgetTester tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ScheduleManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Add Shift button
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    // Verify multi-store selection title and chips exist
    expect(find.text('เลือกร้าน (เลือกได้มากกว่า 1 ร้าน)'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);

    // Tokio Haus is selected by default; tap Kita Cafe to select it as well
    await tester.tap(find.widgetWithText(FilterChip, 'Kita Cafe'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.ensureVisible(find.text('บันทึกกะงาน'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกกะงาน'));
    await tester.pumpAndSettle();

    // Both shifts should be added into the shiftProvider
    final shifts = container.read(shiftProvider).shifts;
    expect(shifts.any((s) => s.storeName == 'Tokio Haus'), isTrue);
    expect(shifts.any((s) => s.storeName == 'Kita Cafe'), isTrue);
  });

  test('LocationService accurately checks 300m radius and coordinates for Kita Stan Tea Surat Thani', () {
    expect(LocationService.targetLatitude, 9.1382);
    expect(LocationService.targetLongitude, 99.3216);
    expect(LocationService.geofenceRadiusMeters, 300.0);
    expect(LocationService.autoCheckInDurationSeconds, 300);

    // Within 300m test
    expect(LocationService.isWithinRadius(50.0), isTrue);
    expect(LocationService.isWithinRadius(300.0), isTrue);
    expect(LocationService.isWithinRadius(301.0), isFalse);
    expect(LocationService.isWithinRadius(1500.0), isFalse);
  });

  testWidgets('TimetableGridWidget renders transparent-to-cloudy gradient for flexible start shifts', (WidgetTester tester) async {
    final regularShift = ShiftModel(
      id: 'reg-shift-1',
      userId: 'user-1',
      userName: 'กานต์',
      storeName: 'Tokio Haus',
      date: DateTime.now(),
      startTime: '10:00',
      endTime: '18:00',
      role: 'Staff',
      branchLocation: '',
    );

    final flexibleShift = ShiftModel(
      id: 'flex-shift-1',
      userId: 'user-1',
      userName: 'กานต์',
      storeName: 'Kita Cafe',
      date: DateTime.now(),
      startTime: 'เลิกเรียนไวที่สุด',
      endTime: '21:30',
      role: 'Staff',
      branchLocation: '',
    );

    expect(regularShift.isFlexibleStart, isFalse);
    expect(flexibleShift.isFlexibleStart, isTrue);

    final today = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              height: 600,
              child: TimetableGridWidget(
                daysOfWeek: [today],
                getShiftsForDay: (date) => [regularShift, flexibleShift],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check flexible shift badge displays school icon & label
    expect(find.byIcon(Icons.school_rounded), findsWidgets);
    expect(find.textContaining('เลิกเรียน'), findsWidgets);
  });
}


