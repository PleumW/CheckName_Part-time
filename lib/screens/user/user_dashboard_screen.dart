import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/shift_model.dart';
import '../../models/notification_model.dart';
import '../../providers/shift_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/shift_detail_sheet.dart';
import '../../widgets/checkout_dialog.dart';
import '../../widgets/user_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_image_view.dart';
import '../../widgets/app_animations.dart';
import 'user_timetable_screen.dart';
import 'user_profile_screen.dart';
import '../../widgets/app_settings_sheet.dart';
import '../../services/web_notification_service.dart';

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  int _currentIndex = 0;
  String _dashboardEarningsFilter = 'all'; // '1d', '7d', '1m', 'all'
  bool _hasNewSchedule = false;

  bool _showPermissionPrompt = true;
  final Set<String> _notifiedShiftIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationService();
    });
  }

  void _initLocationService() {
    ref.read(locationProvider.notifier).startMonitoring(
      onAutoCheckIn: () {
        _triggerAutoCheckIn();
      },
    );
  }

  void _triggerAutoCheckIn() {
    final currentUser = ref.read(authProvider);
    final currentUserId = currentUser?.id ?? '';
    final nickname = currentUser?.nickname ?? '';
    final fullName = currentUser?.displayName ?? '';
    final shiftState = ref.read(shiftProvider);
    final activeShift = currentUserId.isNotEmpty
        ? shiftState.todayShiftForUser(currentUserId, nickname: nickname, fullName: fullName)
        : (shiftState.shiftsForDay(DateTime.now()).isNotEmpty ? shiftState.shiftsForDay(DateTime.now()).first : null);

    if (activeShift != null && activeShift.status == 'scheduled') {
      ref.read(shiftProvider.notifier).checkIn(activeShift.id);
      WebNotificationService.playNotificationSound();
      WebNotificationService.showNotification(
        title: '📍 เช็คอินเข้างานอัตโนมัติสำเร็จ!',
        body: 'ระบบเช็คอินให้คุณที่ ${activeShift.storeName} เรียบร้อยแล้ว เนื่องจากอยู่ในบริเวณร้านครบ 5 นาที ☕🐾',
        tag: 'auto-checkin-${activeShift.id}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 เช็คอินเข้างานอัตโนมัติที่ ${activeShift.storeName} ให้แล้ว เนื่องจากอยู่ในบริเวณร้านครบ 5 นาที ☕🐾'),
            backgroundColor: AppTheme.mocha,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    try {
      ref.read(locationProvider.notifier).stopMonitoring();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeOverview(context),
      const UserTimetableScreen(),
      _buildEarningsAndHistory(context),
      const UserProfileScreen(),
    ];

    final currentUser = ref.watch(authProvider);
    final currentUserId = currentUser?.id ?? '';
    final userNotifs = currentUserId.isNotEmpty
        ? ref.watch(userNotificationsProvider(currentUserId))
        : ref.watch(notificationProvider);
    final unreadCount = currentUserId.isNotEmpty
        ? ref.watch(userUnreadNotificationCountProvider(currentUserId))
        : ref.watch(unreadNotificationCountProvider);

    // Listen to incoming notifications in realtime
    ref.listen<List<AppNotificationModel>>(notificationProvider, (previous, current) {
      if (previous != null && current.isNotEmpty) {
        final prevIds = previous.map((n) => n.id).toSet();
        final newlyAdded = current.where((n) => !prevIds.contains(n.id) && !n.isRead).toList();
        for (final notif in newlyAdded) {
          final isForMe = currentUserId.isEmpty ||
              notif.targetUserId == null ||
              notif.targetUserId!.isEmpty ||
              notif.targetUserId == 'all' ||
              notif.targetUserId == 'user-default' ||
              notif.targetUserId == currentUserId ||
              notif.employeeName == 'พนักงานทั่วไป' ||
              (currentUser != null && (
                 (currentUser.nickname.isNotEmpty && (notif.employeeName.toLowerCase().contains(currentUser.nickname.toLowerCase()) || currentUser.nickname.toLowerCase().contains(notif.employeeName.toLowerCase()))) ||
                 (currentUser.firstName.isNotEmpty && (notif.employeeName.toLowerCase().contains(currentUser.firstName.toLowerCase()) || currentUser.firstName.toLowerCase().contains(notif.employeeName.toLowerCase()))) ||
                 (currentUser.displayName.isNotEmpty && (notif.employeeName.toLowerCase().contains(currentUser.displayName.toLowerCase()) || currentUser.displayName.toLowerCase().contains(notif.employeeName.toLowerCase())))
              ));
          if (isForMe && (notif.type == 'new_shift' || notif.type == 'update_shift')) {
            final dedupeKey = notif.shiftId.isNotEmpty ? notif.shiftId : notif.id;
            if (!_notifiedShiftIds.contains(dedupeKey)) {
              _notifiedShiftIds.add(dedupeKey);
              WebNotificationService.playNotificationSound();
              WebNotificationService.showNotification(
                title: notif.title,
                body: notif.body,
                tag: notif.id,
              );
            }
            setState(() => _hasNewSchedule = true);
          }
        }
      }
    });

    // Listen to incoming shifts in realtime
    ref.listen<ShiftState>(shiftProvider, (previous, current) {
      if (previous != null && current.shifts.isNotEmpty) {
        final prevIds = previous.shifts.map((s) => s.id).toSet();
        final newlyAdded = current.shifts.where((s) => !prevIds.contains(s.id)).toList();
        for (final s in newlyAdded) {
          final isForMe = currentUserId.isEmpty ||
              s.userId.isEmpty ||
              s.userId == 'all' ||
              s.userId == 'user-default' ||
              s.userId == currentUserId ||
              s.userName == 'พนักงานทั่วไป' ||
              (currentUser != null && (
                 (currentUser.nickname.isNotEmpty && (s.userName.toLowerCase().contains(currentUser.nickname.toLowerCase()) || currentUser.nickname.toLowerCase().contains(s.userName.toLowerCase()))) ||
                 (currentUser.firstName.isNotEmpty && (s.userName.toLowerCase().contains(currentUser.firstName.toLowerCase()) || currentUser.firstName.toLowerCase().contains(s.userName.toLowerCase()))) ||
                 (currentUser.displayName.isNotEmpty && (s.userName.toLowerCase().contains(currentUser.displayName.toLowerCase()) || currentUser.displayName.toLowerCase().contains(s.userName.toLowerCase())))
              ));
          if (isForMe) {
            if (!_notifiedShiftIds.contains(s.id)) {
              _notifiedShiftIds.add(s.id);
              final shiftTitle = '📅 มีตารางงานใหม่ถูกกำหนดให้คุณ!';
              final shiftBody = 'ที่ ${s.storeName} วันที่ ${s.date.day}/${s.date.month} เวลา ${s.startTime} - ${s.endTime} น.';
              WebNotificationService.playNotificationSound();
              WebNotificationService.showNotification(
                title: shiftTitle,
                body: shiftBody,
                tag: s.id,
              );
            }
            setState(() => _hasNewSchedule = true);
          }
        }
      }
    });

    final Widget mainScaffold = (_currentIndex == 1 || _currentIndex == 3)
        ? Scaffold(
            body: screens[_currentIndex],
            bottomNavigationBar: _buildBottomNav(),
          )
        : Scaffold(
            appBar: AppBar(
              title: Text(_currentIndex == 0 ? 'หน้าหลัก' : 'รายได้และประวัติ'),
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_rounded),
                      tooltip: 'การแจ้งเตือน (Notifications)',
                      onPressed: () => _showUserNotificationsSheet(context, userNotifs),
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
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
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

    return mainScaffold;
  }

  Widget _buildNotificationPermissionPrompt() {
    final isIOSNotStandalone = WebNotificationService.isIOS && !WebNotificationService.isStandalone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.mocha.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.mocha.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.mocha.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIOSNotStandalone ? Icons.phone_iphone_rounded : Icons.notifications_active_rounded,
              color: AppTheme.mocha,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIOSNotStandalone ? 'วิธีเปิดแจ้งเตือนบน iPhone' : 'เปิดการแจ้งเตือนตารางงาน',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  isIOSNotStandalone
                      ? 'แตะปุ่มแชร์ ⎋ แล้วเลือก "เพิ่มไปยังหน้าจอโฮม" ➕ เพื่อรับแจ้งเตือนเหมือนแอพ Facebook'
                      : 'รับการแจ้งเตือนเมื่อมีกะงานใหม่ทันทีเหมือนแอป Facebook',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: WebNotificationService.isGranted,
            activeThumbColor: AppTheme.mocha,
            activeTrackColor: AppTheme.mocha.withValues(alpha: 0.35),
            onChanged: (val) {
              if (isIOSNotStandalone) {
                _showIOSInstructionDialog(context);
              } else {
                if (val) {
                  WebNotificationService.requestPermission();
                  WebNotificationService.playNotificationSound();
                  WebNotificationService.showNotification(
                    title: 'ChcekName',
                    body: 'เปิดการแจ้งเตือนตารางงานสำเร็จแล้ว! 🔔',
                  );
                }
                setState(() {
                  _showPermissionPrompt = false;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _showPermissionPrompt = false),
          ),
        ],
      ),
    );
  }

  void _showIOSInstructionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.apple, color: AppTheme.mocha, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'วิธีเปิดการแจ้งเตือนบน iPhone',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เนื่องจากระบบปฏิบัติการ iOS (Apple) อนุญาตให้แจ้งเตือนบนหน้าจอล็อกได้เฉพาะเมื่อติดตั้งแอพลงหน้าจอโฮมเท่านั้น:',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
            const SizedBox(height: 14),
            _buildIOSStep('1', 'แตะปุ่มแชร์ (Share ⎋) ที่ขอบล่างของ Safari'),
            const SizedBox(height: 10),
            _buildIOSStep('2', 'เลื่อนลงแล้วเลือก "เพิ่มไปยังหน้าจอโฮม" (Add to Home Screen ➕)'),
            const SizedBox(height: 10),
            _buildIOSStep('3', 'กด "เพิ่ม" (Add) ที่มุมขวาบน'),
            const SizedBox(height: 10),
            _buildIOSStep('4', 'เปิดแอพจากไอคอนบนหน้าจอโฮม แล้วกด "เปิดการแจ้งเตือน"'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.latte.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lightbulb_outline, color: AppTheme.mocha, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'เมื่อเปิดการแจ้งเตือนแล้ว ระบบจะส่งการแจ้งเตือนภายนอกแอพและหน้าจอล็อกพร้อมเสียงกริ่งทันทีครับ',
                      style: TextStyle(fontSize: 11, color: AppTheme.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              WebNotificationService.playNotificationSound();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('เล่นเสียงกริ่งทดสอบเรียบร้อยแล้ว 🎵'),
                  backgroundColor: AppTheme.mocha,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('ทดสอบเสียง 🎵', style: TextStyle(color: AppTheme.mocha)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mocha,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppTheme.mocha,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final currentUser = ref.watch(authProvider);
    final currentUserId = currentUser?.id ?? '';
    final hasUnreadShiftNotif = currentUserId.isNotEmpty
        ? ref.watch(userHasUnreadShiftNotificationProvider(currentUserId))
        : false;
    final showRedDot = _hasNewSchedule || hasUnreadShiftNotif;

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
          if (index == 1) {
            _hasNewSchedule = false;
            if (currentUserId.isNotEmpty) {
              final notifs = ref.read(userNotificationsProvider(currentUserId));
              for (final n in notifs) {
                if (!n.isRead && (n.type == 'new_shift' || n.type == 'update_shift')) {
                  ref.read(notificationProvider.notifier).markAsRead(n.id);
                }
              }
            }
          }
        });
      },
      selectedItemColor: AppTheme.mocha,
      unselectedItemColor: Colors.grey.shade600,
      backgroundColor: Colors.white,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.calendar_month_rounded),
              if (showRedDot)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          label: 'ตารางงาน',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded),
          label: 'รายได้ / ประวัติ',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }

  Widget _buildHomeOverview(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final currentUser = ref.watch(authProvider);
    final today = DateTime.now();

    final currentUserId = currentUser?.id ?? '';
    final nickname = currentUser?.nickname;
    final fullName = currentUser != null && currentUser.firstName.isNotEmpty
        ? '${currentUser.firstName} ${currentUser.lastName}'.trim()
        : null;

    final activeShift = currentUserId.isNotEmpty
        ? shiftState.todayShiftForUser(currentUserId, nickname: nickname, fullName: fullName)
        : (shiftState.shiftsForDay(today).isNotEmpty ? shiftState.shiftsForDay(today).first : null);

    final nextShift = currentUserId.isNotEmpty
        ? shiftState.nextUpcomingShiftForUser(currentUserId, nickname: nickname, fullName: fullName)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final currentUser = ref.watch(authProvider);
                        final userName = currentUser != null && currentUser.nickname.isNotEmpty
                            ? currentUser.nickname
                            : (currentUser != null && currentUser.firstName.isNotEmpty
                                ? currentUser.firstName
                                : 'พนักงาน');
                        return Text(
                          'สวัสดีครับ, คุณ$userName 🐾',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    Text(
                      '${today.day}/${today.month}/${today.year + 543} | ขอให้เป็นวันที่สดใส!',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final currentUser = ref.watch(authProvider);
                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = 3),
                    child: UserAvatar(
                      imageSource: currentUser?.profileImage,
                      radius: 24,
                      fallbackIcon: Icons.pets,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Proactive Notification Permission Prompt (เหมือน Facebook / LINE)
          if (!WebNotificationService.isGranted && _showPermissionPrompt) ...[
            _buildNotificationPermissionPrompt(),
            const SizedBox(height: 16),
          ],

          // Today's Shift Card
          Text(
            'กะงานวันนี้ (Today\'s Shift)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
          ),
          const SizedBox(height: 8),
          FadeSlideTransition(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.mocha.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: activeShift != null
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: activeShift.storeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.storefront_rounded, color: activeShift.storeColor, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            activeShift.storeName,
                                            style: TextStyle(
                                              color: activeShift.storeColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: activeShift.status == 'in_progress'
                                                ? Colors.orange.shade50
                                                : (activeShift.status == 'completed'
                                                    ? Colors.green.shade50
                                                    : AppTheme.latte.withValues(alpha: 0.4)),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: activeShift.status == 'in_progress'
                                                  ? Colors.orange.shade300
                                                  : (activeShift.status == 'completed'
                                                      ? Colors.green.shade300
                                                      : AppTheme.latte),
                                            ),
                                          ),
                                          child: Text(
                                            activeShift.status == 'in_progress'
                                                ? 'กำลังทำงาน 🟢'
                                                : (activeShift.status == 'completed' ? 'เสร็จสิ้น ✨' : 'รอเข้างาน ☕'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: activeShift.status == 'in_progress'
                                                  ? Colors.orange.shade800
                                                  : (activeShift.status == 'completed'
                                                      ? Colors.green.shade800
                                                      : AppTheme.mocha),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.mocha),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${activeShift.startTime} - ${activeShift.endTime} น.',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (activeShift.branchLocation.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              activeShift.branchLocation,
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    // GPS Geofence Check (300m Kita Stan Tea)
                                    _buildGpsGeofenceCard(context, activeShift),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => ShiftDetailSheet.show(context, activeShift),
                                  icon: const Icon(Icons.info_outline, size: 16),
                                  label: const Text('ดูรายละเอียด'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textDark,
                                    side: BorderSide(color: AppTheme.latte),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTodayShiftActionButton(context, activeShift),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.latte.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.free_breakfast_rounded, color: AppTheme.mocha, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'วันนี้ไม่มีกะทำงาน',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'พักผ่อนให้เต็มที่นะครับ ☕',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => setState(() => _currentIndex = 1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.mocha,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  elevation: 0,
                                ),
                                child: const Text('ดูตารางงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          if (nextShift != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: nextShift.storeColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: nextShift.storeColor.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: nextShift.storeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.next_plan_outlined, color: nextShift.storeColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'กะงานถัดไปของคุณ: ',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                              ),
                                              TextSpan(
                                                text: nextShift.storeName,
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nextShift.storeColor),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${_thaiWeekdayName(nextShift.date.weekday)} ${nextShift.date.day}/${nextShift.date.month} • ${nextShift.startTime} - ${nextShift.endTime} น.',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => ShiftDetailSheet.show(context, nextShift),
                                    style: TextButton.styleFrom(
                                      foregroundColor: nextShift.storeColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    child: const Text('ดูรายละเอียด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Timetable Banner Card (เหมือนตารางสอน)
          InkWell(
            onTap: () => setState(() => _currentIndex = 1),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.mocha,
                    AppTheme.mocha.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.mocha.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ตารางงานสไตล์ตารางสอน 📅',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ดูเวลาเข้างาน 08:00 - 21:00 น. แยกตามสาขาและวัน',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Upcoming Shifts Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'กะงานเร็วๆ นี้',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 1),
                child: const Text('ดูทั้งหมด', style: TextStyle(color: AppTheme.mocha)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final todayStart = DateTime(today.year, today.month, today.day);
              final allUpcomingShifts = shiftState.shifts.where((s) {
                final sDate = DateTime(s.date.year, s.date.month, s.date.day);
                return s.status != 'completed' && (sDate.isAtSameMomentAs(todayStart) || sDate.isAfter(todayStart));
              }).toList()
                ..sort((a, b) {
                  final cmp = a.date.compareTo(b.date);
                  if (cmp != 0) return cmp;
                  return a.startTime.compareTo(b.startTime);
                });

              // Show current user's upcoming shifts matching userId, nickname or fullName
              final myUpcomingShifts = currentUserId.isNotEmpty
                  ? shiftState.upcomingShiftsForUser(currentUserId, nickname: nickname, fullName: fullName)
                  : allUpcomingShifts;

              if (myUpcomingShifts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mocha.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.latte.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_note_rounded, size: 30, color: AppTheme.mocha),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ยังไม่มีกะงานที่ได้รับมอบหมายในขณะนี้',
                        style: TextStyle(color: AppTheme.textDark, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เมื่อแอดมินจัดตารางงาน จะแจ้งเตือนให้คุณทราบทันทีครับ ☕',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      if (allUpcomingShifts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() => _currentIndex = 1),
                          icon: const Icon(Icons.table_chart_rounded, size: 16, color: AppTheme.mocha),
                          label: Text(
                            'มีกะงานของเพื่อนร่วมงาน ${allUpcomingShifts.length} กะ (แตะดูตารางรวม)',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mocha, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return Column(
                children: myUpcomingShifts.take(4).map((shift) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.mocha.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: shift.storeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.storefront_rounded, color: shift.storeColor, size: 22),
                        ),
                        title: Row(
                          children: [
                            Text(
                              shift.storeName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: shift.storeColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (shift.status == 'in_progress')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: const Text(
                                  'กำลังทำงาน 🟢',
                                  style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${_thaiWeekdayName(shift.date.weekday)} ${shift.date.day}/${shift.date.month} • ${shift.startTime} - ${shift.endTime} น.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: shift.storeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            shift.role,
                            style: TextStyle(fontSize: 11, color: shift.storeColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        onTap: () => ShiftDetailSheet.show(context, shift),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  List<ShiftModel> _filterShiftsByTime(List<ShiftModel> shifts, String filter) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case '1d':
        return shifts.where((s) {
          final sDate = DateTime(s.date.year, s.date.month, s.date.day);
          return sDate.isAtSameMomentAs(todayStart) || s.date.isAfter(now.subtract(const Duration(hours: 24)));
        }).toList();
      case '7d':
        final start = now.subtract(const Duration(days: 7));
        return shifts.where((s) => s.date.isAfter(start)).toList();
      case '1m':
        final start = now.subtract(const Duration(days: 30));
        return shifts.where((s) => s.date.isAfter(start)).toList();
      case 'all':
      default:
        return shifts;
    }
  }

  Widget _buildEarningsAndHistory(BuildContext context) {
    final currentUser = ref.watch(authProvider);
    final shiftState = ref.watch(shiftProvider);
    final notifications = ref.watch(notificationProvider);

    final paymentNotifs = notifications.where((n) {
      if (n.type != 'payment_slip') return false;
      if (currentUser != null && n.targetUserId != null && n.targetUserId!.isNotEmpty) {
        return n.targetUserId == currentUser.id;
      }
      return true;
    }).toList();

    final allCompletedShifts = shiftState.shifts.where((s) {
      if (s.status != 'completed') return false;
      if (currentUser != null && s.userId.isNotEmpty && s.userId != currentUser.id) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final filteredShifts = _filterShiftsByTime(allCompletedShifts, _dashboardEarningsFilter);
    final totalHours = filteredShifts.fold(0.0, (sum, s) => sum + s.durationHours);
    final estimatedEarnings = filteredShifts.fold(0.0, (sum, s) => sum + s.calculatedEarnings).toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('สรุปรายได้และชั่วโมงทำงาน', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Payment Slip Notifications Banner (If Admin sent payment)
          if (paymentNotifs.isNotEmpty) ...[
            ...paymentNotifs.take(2).map((pNotif) {
              return Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.green.shade300, width: 1.2),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.green, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pNotif.title,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pNotif.body,
                        style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                      ),
                      if (pNotif.slipImage != null && pNotif.slipImage!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            const Text('สลิปการโอนเงิน (แตะเพื่อดูรูปใหญ่)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AppImageView(
                          imageSource: pNotif.slipImage!,
                          width: 120,
                          height: 120,
                          borderRadius: BorderRadius.circular(10),
                          enableFullScreenOnTap: true,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],

          // Timeframe Filter Chips
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.latte),
            ),
            child: Row(
              children: [
                _buildDashboardFilterChip('1d', '1 วัน'),
                _buildDashboardFilterChip('7d', '7 วัน'),
                _buildDashboardFilterChip('1m', '1 เดือน'),
                _buildDashboardFilterChip('all', 'ยอดรวม'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.mocha.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.latte.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.timer_outlined, size: 18, color: AppTheme.mocha),
                          ),
                          const SizedBox(width: 10),
                          const Text('ชั่วโมงทำงานสะสม', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      Text('${totalHours.toStringAsFixed(1)} ชม.',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.mocha, fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.payments_outlined, size: 18, color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 10),
                          const Text('ประมาณการรายได้ (40 บ./ชม.)', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          '$estimatedEarnings บาท',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ประวัติการเช็คอินที่ผ่านมา',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (filteredShifts.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                  label: const Text(
                    'ล้างประวัติทั้งหมด',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _confirmClearAllHistory(context, allCompletedShifts),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredShifts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.mocha.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.latte.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded, size: 28, color: AppTheme.mocha),
                  ),
                  const SizedBox(height: 10),
                  const Text('ยังไม่มีประวัติการทำงานที่เสร็จสิ้น', style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('เมื่อคุณ Check In และ Check Out เรียบร้อย ประวัติงานจะแสดงที่นี่ครับ ☕', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            )
          else
            ...filteredShifts.map((shift) {
              final earnings = shift.calculatedEarnings.toInt();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.latte.withValues(alpha: 0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.mocha.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    ),
                    title: Text('${shift.storeName} - ${shift.role}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                        '${shift.date.day}/${shift.date.month}/${shift.date.year + 543} • ${shift.startTime} - ${shift.endTime} (${shift.durationHours.toStringAsFixed(0)} ชม.)',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text('+$earnings ฿', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 13)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'ลบประวัติเช็คอินนี้ออกจากฐานข้อมูล',
                          onPressed: () => _confirmDeleteCompletedShift(context, shift),
                        ),
                      ],
                    ),
                    onTap: () => ShiftDetailSheet.show(context, shift),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _confirmDeleteCompletedShift(BuildContext context, ShiftModel shift) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบประวัติการเช็คอิน'),
        content: Text('คุณต้องการลบประวัติการเช็คอินของ ${shift.storeName} (${shift.startTime} - ${shift.endTime}) ออกจากฐานข้อมูล Database ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(shiftProvider.notifier).deleteShift(shift.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ลบประวัติการเช็คอินออกจาก Database เรียบร้อยแล้ว'),
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

  void _confirmClearAllHistory(BuildContext context, List<ShiftModel> shifts) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้างประวัติการเช็คอินทั้งหมด'),
        content: Text('คุณต้องการลบประวัติการเช็คอินทั้งหมด ${shifts.length} รายการ ออกจากฐานข้อมูล Database ใช่หรือไม่? ข้อมูลจะถูกลบถาวร'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              for (final s in shifts) {
                ref.read(shiftProvider.notifier).deleteShift(s.id);
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ล้างประวัติการเช็คอินทั้งหมดออกจาก Database เรียบร้อยแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ล้างทั้งหมด', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsGeofenceCard(BuildContext context, ShiftModel activeShift) {
    final loc = ref.watch(locationProvider);

    if (loc.isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.latte.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.mocha),
            ),
            SizedBox(width: 8),
            Text('กำลังตรวจสอบระยะพิกัดร้าน Kita Stan Tea (GPS)...', style: TextStyle(fontSize: 11, color: AppTheme.textDark)),
          ],
        ),
      );
    }

    if (loc.isInRange) {
      final distStr = loc.distanceMeters != null ? '${loc.distanceMeters!.toStringAsFixed(0)} ม.' : '< 300 ม.';
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 อยู่ในระยะร้าน Kita Stan Tea สุราษฎร์ฯ ($distStr)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                  ),
                  if (activeShift.status == 'scheduled')
                    Text(
                      loc.enteredGeofenceAt != null
                          ? '⏱️ เข้าบริเวณร้านแล้ว (หากลืมกด ระบบจะเช็คอินให้อัตโนมัติใน 5 นาที)'
                          : 'สามารถกด Check In ด้านล่างเพื่อเข้างานได้ทันที 🐾',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Outside 300m
    final distStr = loc.distanceMeters != null
        ? (loc.distanceMeters! >= 1000
            ? '${(loc.distanceMeters! / 1000).toStringAsFixed(2)} กม.'
            : '${loc.distanceMeters!.toStringAsFixed(0)} ม.')
        : 'กำลังระบุ';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: Colors.amber.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 ห่างจาก Kita Stan Tea สุราษฎร์ฯ: ~$distStr',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                ),
                const Text(
                  'เช็คอินได้เมื่ออยู่ในรัศมี 300 ม. ของร้าน ☕',
                  style: TextStyle(fontSize: 11, color: AppTheme.textDark),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(locationProvider.notifier).requestPermissionAndCheck(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: AppTheme.mocha,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'รีเฟรช GPS',
          ),
        ],
      ),
    );
  }

  void _showOutOfRangeDialog(BuildContext context, LocationState loc, ShiftModel activeShift) {
    final distanceText = loc.distanceMeters != null
        ? (loc.distanceMeters! >= 1000
            ? '${(loc.distanceMeters! / 1000).toStringAsFixed(2)} กม.'
            : '${loc.distanceMeters!.toStringAsFixed(0)} เมตร')
        : 'ยังไม่สามารถระบุระยะได้';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.location_off_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 8),
            Text('อยู่นอกระยะร้าน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การเช็คอินเข้างานต้องอยู่ในรัศมี 300 เมตรของ Kita Stan Tea สาขาสุราษฎร์ธานี',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ระยะปัจจุบัน: $distanceText (กำหนดรัศมี 300 ม.)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'กรุณาเดินทางไปยังร้าน หรือกดอัปเดตพิกัด GPS อีกครั้ง',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('เข้าใจแล้ว'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(locationProvider.notifier).refreshLocation();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('อัปเดต GPS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mocha,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayShiftActionButton(BuildContext context, ShiftModel activeShift) {
    if (activeShift.status == 'in_progress') {
      return ElevatedButton.icon(
        onPressed: () => CheckoutDialog.show(context, activeShift),
        icon: const Icon(Icons.camera_alt_rounded, size: 16),
        label: const Text('Check Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          elevation: 0,
        ),
      );
    } else if (activeShift.status == 'completed') {
      return ElevatedButton.icon(
        onPressed: () => ShiftDetailSheet.show(context, activeShift),
        icon: const Icon(Icons.check_circle_rounded, size: 16),
        label: const Text('เสร็จสิ้น'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          elevation: 0,
        ),
      );
    } else {
      final loc = ref.watch(locationProvider);
      return ElevatedButton.icon(
        onPressed: () {
          if (loc.isPermissionGranted && !loc.isInRange) {
            _showOutOfRangeDialog(context, loc, activeShift);
            return;
          }
          ref.read(shiftProvider.notifier).checkIn(activeShift.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เช็คอินที่ ${activeShift.storeName} สำเร็จ! กำลังปฏิบัติงาน 🐾'),
              backgroundColor: AppTheme.mocha,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        icon: const Icon(Icons.fingerprint_rounded, size: 16),
        label: const Text('Check In'),
        style: ElevatedButton.styleFrom(
          backgroundColor: (loc.isPermissionGranted && !loc.isInRange) ? Colors.grey.shade600 : activeShift.storeColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          elevation: 0,
        ),
      );
    }
  }

  String _thaiWeekdayName(int weekday) {
    const days = ['', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัส', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์'];
    return days[weekday];
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม. ที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }

  void _showUserNotificationsSheet(BuildContext context, List<AppNotificationModel> notifications) {
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
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, color: AppTheme.mocha, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'การแจ้งเตือนของคุณ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                    ],
                  ),
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
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text('ยังไม่มีการแจ้งเตือนใหม่', style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, idx) {
                          final notif = notifications[idx];
                          final isUnread = !notif.isRead;

                          IconData notifIcon = Icons.notifications_rounded;
                          Color iconColor = AppTheme.mocha;
                          Color iconBg = AppTheme.mocha.withValues(alpha: 0.12);

                          if (notif.type == 'new_shift') {
                            notifIcon = Icons.calendar_today_rounded;
                            iconColor = const Color(0xFF5C6BC0);
                            iconBg = const Color(0xFFE8EAF6);
                          } else if (notif.type == 'update_shift') {
                            notifIcon = Icons.edit_calendar_rounded;
                            iconColor = const Color(0xFFFF8F00);
                            iconBg = const Color(0xFFFFF3E0);
                          } else if (notif.type == 'payment_slip') {
                            notifIcon = Icons.verified_rounded;
                            iconColor = Colors.green.shade800;
                            iconBg = Colors.green.shade100;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isUnread ? AppTheme.latte.withValues(alpha: 0.25) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isUnread ? AppTheme.mocha.withValues(alpha: 0.3) : Colors.grey.shade200,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconBg,
                                child: Icon(notifIcon, color: iconColor, size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 14,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  if (isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    notif.body,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeAgo(notif.timestamp),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
                                onPressed: () {
                                  ref.read(notificationProvider.notifier).deleteNotification(notif.id);
                                },
                              ),
                              onTap: () {
                                ref.read(notificationProvider.notifier).markAsRead(notif.id);
                                if (notif.shiftId.isNotEmpty) {
                                  final shift = ref.read(shiftProvider).shifts
                                      .where((s) => s.id == notif.shiftId)
                                      .firstOrNull;
                                  if (shift != null) {
                                    Navigator.pop(ctx);
                                    ShiftDetailSheet.show(context, shift);
                                  }
                                }
                              },
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

  Widget _buildDashboardFilterChip(String filterKey, String label) {
    final isSelected = _dashboardEarningsFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _dashboardEarningsFilter = filterKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.mocha : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
        ),
      ),
    );
  }
}
