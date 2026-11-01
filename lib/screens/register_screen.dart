import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_avatar.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nicknameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String? _emailError;
  String? _profileImageBase64;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bankAccountController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _profileImageBase64 = 'data:image/jpeg;base64,$base64Str';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเลือกรูปภาพได้: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เลือกรูปโปรไฟล์',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.mocha),
                title: const Text('ถ่ายภาพด้วยกล้อง'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.matcha),
                title: const Text('เลือกจากคลังรูปภาพ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageBase64 != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('ลบรูปภาพ', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _profileImageBase64 = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _register() async {
    final nickname = _nicknameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final bankAccount = _bankAccountController.text.trim();

    if (firstName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อจริง อีเมล และรหัสผ่าน')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      await ref.read(authProvider.notifier).register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        nickname: nickname,
        bankAccount: bankAccount,
        profileImage: _profileImageBase64,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pop(); // Go back to login
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลงทะเบียนสำเร็จ! กรุณาเข้าสู่ระบบด้วยบัญชีของคุณ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final errStr = e.toString();
      if (errStr.contains('email-already-in-use')) {
        setState(() {
          _emailError = 'อีเมลนี้ถูกใช้งานแล้วในระบบ (Email ซ้ำ)';
        });
        _showDuplicateEmailDialog(email);
        return;
      }

      String errorMessage;
      if (errStr.contains('weak-password')) {
        errorMessage = 'รหัสผ่านสั้นเกินไป กรุณาตั้งรหัสผ่านอย่างน้อย 6 ตัวอักษร';
      } else if (errStr.contains('invalid-email')) {
        errorMessage = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else if (errStr.contains('network-request-failed')) {
        errorMessage = 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ';
      } else {
        errorMessage = 'ลงทะเบียนไม่สำเร็จ: ${errStr.replaceAll("Exception: ", "")}';
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

  void _showDuplicateEmailDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'อีเมลซ้ำในระบบ!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: 'อีเมล ',
                style: const TextStyle(fontSize: 15),
                children: [
                  TextSpan(
                    text: email,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.mocha),
                  ),
                  const TextSpan(text: ' มีการลงทะเบียนในระบบ Firebase เรียบร้อยแล้ว (Email ซ้ำ)\n\n'),
                  const TextSpan(text: '• หากนี่เป็นบัญชีของคุณ สามารถกด "ไปหน้าเข้าสู่ระบบ" เพื่อล็อกอินได้ทันที\n'),
                  const TextSpan(text: '• หรือกด "เปลี่ยนอีเมล" เพื่อใช้อีเมลอื่นในการสมัคร'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('เปลี่ยนอีเมล'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to login screen
            },
            child: const Text('ไปหน้าเข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.milk,
      appBar: AppBar(
        title: const Text('สมัครสมาชิก (Register)'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Profile Image Picker
                      GestureDetector(
                        onTap: _showImagePickerModal,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            UserAvatar(
                              imageSource: _profileImageBase64,
                              radius: 46,
                              fallbackIcon: Icons.person,
                              backgroundColor: AppTheme.mocha.withValues(alpha: 0.12),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.mocha,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showImagePickerModal,
                        icon: const Icon(Icons.add_a_photo, size: 16, color: AppTheme.mocha),
                        label: Text(
                          _profileImageBase64 == null ? 'เพิ่มรูปโปรไฟล์' : 'เปลี่ยนรูปโปรไฟล์',
                          style: const TextStyle(color: AppTheme.mocha, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nickname field
                      TextField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อเล่น (Nickname)',
                          hintText: 'เช่น บอม, ปอย, มีน',
                          prefixIcon: const Icon(Icons.tag_faces_rounded, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // First Name
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อจริง (First Name) *',
                          prefixIcon: const Icon(Icons.person, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Last Name
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'นามสกุล (Last Name)',
                          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Account
                      TextField(
                        controller: _bankAccountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'เลขที่บัญชีธนาคาร (Bank Account)',
                          hintText: 'เช่น 123-4-56789-0',
                          prefixIcon: const Icon(Icons.account_balance, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'อีเมล (Email) *',
                          errorText: _emailError,
                          prefixIcon: const Icon(Icons.email, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'รหัสผ่าน (Password) *',
                          prefixIcon: const Icon(Icons.lock, color: AppTheme.mocha),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('สร้างบัญชีผู้ใช้', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    );
  }
}
