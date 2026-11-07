import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/widgets/app_background.dart';

/// Dismisses the keyboard whenever the user navigates between pages.
/// Attach to every Navigator (root + nested tab navigators).
class DismissKeyboardOnNav extends NavigatorObserver {
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route route, Route? previousRoute) => _unfocus();

  @override
  void didPop(Route route, Route? previousRoute) => _unfocus();

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => _unfocus();
}

/// The shell shared by every AidVise app (the main app and the admin panel):
/// theme, background, root navigator, keyboard handling and session rules.
/// Each app supplies only its title and the screen it opens on.
class AppFrame extends StatefulWidget {
  final String title;
  final Widget home;
  const AppFrame({super.key, required this.title, required this.home});

  @override
  State<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<AppFrame> with WidgetsBindingObserver {
  Timer? _sessionTimer;

  static const _idleLimit = Duration(minutes: 5);
  static const _refreshTokenAfter = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    installSessionGuard(); // any 401 ejects the user, whoever made the call
    _sessionTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _enforceSession());
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding suspends the timer; check immediately on return so a
    // long absence logs out right away instead of at the next tick.
    if (state == AppLifecycleState.resumed) _enforceSession();
  }

  /// AFK guard + sliding session: idle 5 minutes -> log out; active with an
  /// aging token -> silently refresh so the 30-minute expiry never
  /// interrupts someone mid-task.
  Future<void> _enforceSession() async {
    if (!await ApiService.isLoggedIn()) {
      // Token gone but an account still on file: the session died mid-use
      // (expired or revoked). Never leave a signed-out user inside the app.
      if (await ApiService.hasStoredAccount()) {
        await forceLogout('You have been logged out. Please log in again.');
      }
      return;
    }
    final idle = DateTime.now().difference(ApiService.lastActivity);
    if (idle >= _idleLimit) {
      await forceLogout(
          'You have been logged out after 5 minutes of inactivity.');
      return;
    }
    final age = await ApiService.tokenAge();
    if (age != null && age > _refreshTokenAfter) {
      try {
        await ApiService.refreshToken();
      } catch (_) {} // next real call surfaces any auth problem
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.title,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [DismissKeyboardOnNav()],
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: AppTheme.primary,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: AppTheme.primary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppTheme.primary),
        ),
      ),
      // Global handlers: every touch feeds the AFK monitor, and tapping
      // outside any text field closes the keyboard on every screen.
      builder: (context, child) {
        return AppBackground(
            child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => ApiService.recordActivity(),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              final focus = FocusManager.instance.primaryFocus;
              if (focus != null) focus.unfocus();
            },
            child: child,
          ),
        ));
      },
      home: widget.home,
    );
  }
}
