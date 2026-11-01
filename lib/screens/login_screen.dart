import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'admin/admin_dashboard_screen.dart';
import 'user/user_dashboard_screen.dart';
import 'register_screen.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่าน')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authProvider.notifier).signIn(
        email: email,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user.role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String errorMessage;
      final errStr = e.toString();
      if (errStr.contains('user-not-found') || errStr.contains('wrong-password') || errStr.contains('invalid-credential')) {
        errorMessage = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      } else if (errStr.contains('invalid-email')) {
        errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else if (errStr.contains('network-request-failed')) {
        errorMessage = 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาลองใหม่อีกครั้ง';
      } else {
        errorMessage = 'เข้าสู่ระบบไม่สำเร็จ: ${errStr.replaceAll("Exception: ", "")}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade400,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: AppTheme.mocha),
            SizedBox(width: 8),
            Text('ลืมรหัสผ่าน (Reset Password)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรอกอีเมลของคุณเพื่อรับลิงก์รีเซ็ตรหัสผ่านใหม่ผ่านทางอีเมล',
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'อีเมลของคุณ',
                hintText: 'example@email.com',
                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.mocha),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('กรุณากรอกอีเมลให้ถูกต้อง')),
                );
                return;
              }
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).resetPassword(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านไปยัง $email เรียบร้อยแล้ว! 📧'),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('ส่งลิงก์รีเซ็ต'),
          ),
        ],
      ),
    );
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.milk,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.mocha.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 60, color: AppTheme.mocha),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.mocha,
                      fontSize: 32,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'ChcekName',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accentPink,
                    ),
              ),
              const SizedBox(height: 36),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'ลืมรหัสผ่าน?',
                            style: TextStyle(color: AppTheme.mocha, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _navigateToRegister,
                        child: const Text(
                          'ยังไม่มีบัญชีใช่หรือไม่? สมัครสมาชิกที่นี่',
                          style: TextStyle(color: AppTheme.mocha, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
