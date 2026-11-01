import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_settings_sheet.dart';
import '../login_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
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
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    final nickname = user?.nickname.isNotEmpty == true ? user!.nickname : 'พนักงาน';
    final fullName = user?.fullName.isNotEmpty == true ? user!.fullName : 'ยังไม่ได้ระบุชื่อ-นามสกุล';
    final email = user?.email.isNotEmpty == true ? user!.email : 'ไม่มีอีเมล';
    final bankAccount = user?.bankAccount.isNotEmpty == true ? user!.bankAccount : 'ยังไม่ได้ระบุ';

    return Scaffold(
      backgroundColor: AppTheme.milk,
      appBar: AppBar(
        title: const Text('โปรไฟล์ของฉัน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'การตั้งค่า (Settings)',
            onPressed: () => AppSettingsSheet.show(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                // Top Lanyard Strap & Clip Simulation
                _buildLanyardClip(),

                // The Employee ID Card Container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mocha.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: AppTheme.latte.withValues(alpha: 0.8), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      // Card Header Banner
                      _buildCardHeader(),

                      // Card Body
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          children: [
                            // Avatar Photo with ID Badge Frame
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.mocha,
                                          AppTheme.latte,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.mocha.withValues(alpha: 0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: UserAvatar(
                                        imageSource: user?.profileImage,
                                        radius: 46,
                                        fallbackIcon: Icons.pets,
                                        backgroundColor: AppTheme.milk,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.matcha,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        '● ACTIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Employee Name & Position
                            Text(
                              nickname,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Divider line
                            Container(
                              height: 1,
                              color: AppTheme.latte.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 14),

                            // Information Table
                            _buildInfoRow(
                              icon: Icons.tag_faces_rounded,
                              label: 'ชื่อเล่น',
                              value: nickname,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow(
                              icon: Icons.badge_outlined,
                              label: 'ชื่อ - นามสกุล',
                              value: fullName,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow(
                              icon: Icons.email_outlined,
                              label: 'อีเมล',
                              value: email,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow(
                              icon: Icons.account_balance_outlined,
                              label: 'เลขที่บัญชีรับเงิน',
                              value: bankAccount,
                              trailing: bankAccount != 'ยังไม่ได้ระบุ'
                                  ? IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.mocha),
                                      tooltip: 'คัดลอกเลขบัญชี',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: bankAccount));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('คัดลอกเลขบัญชีเรียบร้อยแล้ว 📋'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Logout button
                TextButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.grey),
                  label: const Text('ออกจากระบบ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanyardClip() {
    return Column(
      children: [
        // Lanyard Ribbon
        Container(
          width: 32,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.mocha,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 4,
              height: double.infinity,
              color: AppTheme.latte.withValues(alpha: 0.5),
            ),
          ),
        ),
        // Metallic Clip Ring
        Container(
          width: 44,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade600, width: 1.5),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade400,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Lanyard Hole Gap
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

  Widget _buildCardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.mocha,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        gradient: LinearGradient(
          colors: [
            AppTheme.mocha,
            AppTheme.mocha.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, color: AppTheme.mocha, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'CHCEKNAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'STAFF IDENTIFICATION BADGE • JAPANESE THEME',
                      style: TextStyle(
                        color: Color(0xFFE8DCCF),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_rounded, color: Color(0xFFE8DCCF), size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(
              child: Text(
                'STAFF IDENTIFICATION BADGE • บัตรประจำตัวพนักงาน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.milk.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.latte.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.mocha),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }
}
