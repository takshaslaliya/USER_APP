import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/core/services/auth_service.dart';
import 'package:splitease_test/auth/screens/intro_screen.dart';
import 'package:splitease_test/auth/screens/login_screen.dart';
import 'package:splitease_test/auth/screens/reset_password_screen.dart';
import 'package:splitease_test/auth/screens/verify_otp_screen.dart';
import 'package:splitease_test/user/screens/home_screen.dart';
import 'package:splitease_test/user/screens/group_details_screen.dart';
import 'package:splitease_test/core/models/group_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load theme settings before app launch
  final prefs = await SharedPreferences.getInstance();
  final initialIsDark = prefs.getBool('isDark') ?? false;
  final initialThemeName = prefs.getString('themeName') ?? 'purple';

  final themeProvider = ThemeProvider(
    initialIsDark: initialIsDark,
    initialThemeName: initialThemeName,
  );

  final loggedIn = await AuthService.isLoggedIn();

  runApp(
    ChangeNotifierProvider<ThemeProvider>.value(
      value: themeProvider,
      child: SplitEaseApp(initialRoute: loggedIn ? '/home' : '/'),
    ),
  );
}

class SplitEaseApp extends StatelessWidget {
  final String initialRoute;
  const SplitEaseApp({super.key, this.initialRoute = '/'});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'SplitEase',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const IntroScreen();
            break;
          case '/login':
            page = const LoginScreen();
            break;
          case '/verify-otp':
            final email = settings.arguments as String;
            page = VerifyOtpScreen(email: email);
            break;
          case '/reset-password':
            page = const ResetPasswordScreen();
            break;
          case '/home':
            page = const HomeScreen();
            break;
          case '/details':
            final group = settings.arguments as GroupModel;
            page = GroupDetailsScreen(group: group);
            break;
          default:
            page = const IntroScreen();
        }
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
        );
      },
    );
  }
}
