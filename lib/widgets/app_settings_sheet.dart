import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../services/web_notification_service.dart';
import 'user_avatar.dart';

class AppSettingsSheet extends ConsumerStatefulWidget {
  const AppSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppSettingsSheet(),
    );
  }

  @override
  ConsumerState<AppSettingsSheet> createState() => _AppSettingsSheetState();
}

class _AppSettingsSheetState extends ConsumerState<AppSettingsSheet> {
  bool _isNotificationActive = false;

  @override
  void initState() {
    super.initState();
    _isNotificationActive = WebNotificationService.isGranted;
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('ยืนยันออกจากระบบ', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('คุณต้องการออกจากระบบ ChcekName หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              if (mounted) {
                Navigator.pop(context); // Close bottom sheet
              }
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserModel userModel) {
    final nicknameController = TextEditingController(text: userModel.nickname);
    final firstNameController = TextEditingController(text: userModel.firstName);
    final lastNameController = TextEditingController(text: userModel.lastName);
    final emailController = TextEditingController(text: userModel.email);
    final bankAccountController = TextEditingController(text: userModel.bankAccount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppTheme.mocha, size: 26),
            SizedBox(width: 8),
            Text('แก้ไขข้อมูลส่วนตัว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nicknameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อเล่น (Nickname)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.mocha),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อจริง (First Name)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.mocha),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(
                  labelText: 'นามสกุล (Last Name)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person_outline, color: AppTheme.mocha),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล (Email)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.mocha),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankAccountController,
                decoration: InputDecoration(
                  labelText: 'เลขที่บัญชีธนาคาร & ชื่อธนาคาร',
                  hintText: 'เช่น กสิกรไทย 123-4-56789-0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_balance_outlined, color: AppTheme.mocha),
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
            onPressed: () async {
              final updatedUser = userModel.copyWith(
                nickname: nicknameController.text.trim(),
                firstName: firstNameController.text.trim(),
                lastName: lastNameController.text.trim(),
                email: emailController.text.trim(),
                bankAccount: bankAccountController.text.trim(),
              );

              await ref.read(authProvider.notifier).updateUserProfile(updatedUser);
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('อัปเดตข้อมูลส่วนตัวเรียบร้อยแล้ว! ✏️'),
                    backgroundColor: AppTheme.mocha,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('บันทึกข้อมูล', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mocha,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNotificationToggle(BuildContext context, bool enable) async {
    final isIOSNotStandalone = WebNotificationService.isIOS && !WebNotificationService.isStandalone;

    if (enable) {
      if (isIOSNotStandalone) {
        _showIOSInstructionDialog(context);
        return;
      }
      WebNotificationService.playNotificationSound();
      WebNotificationService.requestPermission();
      WebNotificationService.showNotification(
        title: 'ChcekName',
        body: 'เปิดการแจ้งเตือนตารางงานเรียบร้อยแล้ว! 🔔',
      );
      setState(() {
        _isNotificationActive = true;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปิดการแจ้งเตือนภายนอกแอพและเล่นเสียงทดสอบแล้ว 🔔'),
            backgroundColor: AppTheme.mocha,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() {
        _isNotificationActive = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ปิดการแจ้งเตือนแล้ว 🔕'),
            backgroundColor: AppTheme.mocha,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
              'เนื่องจากระบบ iOS อนุญาตให้แจ้งเตือนภายนอกแอพได้เฉพาะเมื่อติดตั้งแอพลงหน้าจอโฮมเท่านั้น:',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
            const SizedBox(height: 14),
            _buildIOSStep('1', 'แตะปุ่มแชร์ (Share ⎋) ที่แถบล่างของ Safari'),
            const SizedBox(height: 10),
            _buildIOSStep('2', 'เลื่อนลงแล้วเลือก "เพิ่มไปยังหน้าจอโฮม" (Add to Home Screen ➕)'),
            const SizedBox(height: 10),
            _buildIOSStep('3', 'กด "เพิ่ม" (Add) ที่มุมขวาบน'),
            const SizedBox(height: 10),
            _buildIOSStep('4', 'เปิดแอพจากไอคอนที่หน้าจอโฮม แล้วเปิดสวิตช์แจ้งเตือนได้ทันที'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              WebNotificationService.playNotificationSound();
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
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final nickname = user?.nickname.isNotEmpty == true ? user!.nickname : 'พนักงาน';
    final fullName = user?.fullName.isNotEmpty == true ? user!.fullName : 'ChcekName';
    final roleText = user?.role == 'admin' ? 'ผู้ดูแลระบบ (Admin)' : 'พนักงาน (Staff)';

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.settings_rounded, color: AppTheme.mocha, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'การตั้งค่า (Settings)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // User info tile
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.milk,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.latte.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    imageSource: user?.profileImage,
                    radius: 26,
                    fallbackIcon: Icons.pets,
                    backgroundColor: AppTheme.mocha.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          fullName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '🐾 $roleText',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.mocha,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action 1: Edit Profile
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.mocha.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.badge_outlined, color: AppTheme.mocha, size: 22),
            ),
            title: const Text(
              'แก้ไขข้อมูลส่วนตัว',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
            ),
            subtitle: const Text(
              'ชื่อเล่น, ชื่อ-นามสกุล, เลขที่บัญชีธนาคาร',
              style: TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            onTap: () {
              if (user != null) {
                _showEditProfileDialog(context, user);
              }
            },
          ),
          const Divider(height: 1, indent: 64),

          // Action 2: Notification Toggle / Request
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_active_rounded, color: Colors.amber.shade900, size: 22),
            ),
            title: const Text(
              'เปิดการแจ้งเตือน',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
            ),
            subtitle: const Text(
              'รับแจ้งเตือนสลิปเงินเดือน, กะงาน, ใบลา',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Switch(
              value: _isNotificationActive,
              activeThumbColor: AppTheme.mocha,
              activeTrackColor: AppTheme.mocha.withValues(alpha: 0.35),
              onChanged: (bool value) => _handleNotificationToggle(context, value),
            ),
            onTap: () => _handleNotificationToggle(context, !_isNotificationActive),
          ),
          const Divider(height: 1, indent: 64),

          // Action 3: About App info
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.matcha.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pets, color: AppTheme.matcha, size: 22),
            ),
            title: const Text(
              'ChcekName',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
            ),
            subtitle: const Text(
              'เวอร์ชัน 1.0.0 (Web & PWA)',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Action 4: Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
