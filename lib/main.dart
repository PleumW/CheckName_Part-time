import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/user/user_dashboard_screen.dart';
import 'providers/auth_provider.dart';
import 'widgets/app_animations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: ChcekNameApp()));
}

class ChcekNameApp extends StatelessWidget {
  const ChcekNameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChcekName',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Restore session from SharedPreferences / Firebase
    final sessionUser = await ref.read(authProvider.notifier).restoreSavedSession();

    if (!mounted) return;

    final currentUser = sessionUser ?? ref.read(authProvider);

    if (currentUser != null) {
      if (currentUser.role == 'admin') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.milk,
      body: Center(
        child: FadeSlideTransition(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BobbingWidget(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mocha.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 80, color: AppTheme.mocha),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ChcekName',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.mocha,
                      fontSize: 28,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Attendance System',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.accentPink,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
