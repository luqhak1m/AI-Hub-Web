import 'package:flutter/material.dart';
import 'package:aidvise_platform/admin/admin_shell.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/user/screens/home_screen.dart';
import 'package:aidvise_platform/vendor/screens/vendor_screen.dart';

enum _Area { admin, vendor, user }

/// The one place that knows about every area. Verifies the stored session
/// with the server, then opens the area for the account type: admin panel,
/// employer workspace, or job seeker home. Anything unverified goes to login.
///
/// The server enforces every permission; this only decides what to show.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  /// Resolved once — creating the future in build() would restart the check
  /// on every rebuild.
  late final Future<_Area?> _area = _resolve();

  Future<_Area?> _resolve() async {
    if (!await ApiService.isLoggedIn()) {
      // No token but an account still on file: the session ended without
      // the user signing out — say so on the login screen.
      if (await ApiService.hasStoredAccount()) {
        await ApiService.logout(notice: 'You have been logged out. Please log in again.');
      }
      return null;
    }
    // The gate reports the result itself; muting the hook keeps a startup
    // 401 from stacking an expiry dialog on top of the login screen.
    final hook = ApiService.onUnauthorized;
    ApiService.onUnauthorized = null;
    try {
      final me = await ApiService.getMe(refresh: true).timeout(const Duration(seconds: 8));
      if (me['is_admin'] == true) return _Area.admin;
      if (me['is_vendor'] == true) return _Area.vendor;
      return _Area.user;
    } on ApiException catch (e) {
      if (e.statusCode != 401) {
        await ApiService.logout(notice: 'Could not verify your session. Please log in again.');
      }
    } catch (_) {
      await ApiService.logout(
          notice: 'Could not reach the server to verify your session. Please log in again.');
    } finally {
      ApiService.onUnauthorized = hook;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Area?>(
      future: _area,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        return switch (snapshot.data) {
          _Area.admin => const AdminShell(),
          _Area.vendor => const VendorScreen(),
          _Area.user => const HomeScreen(),
          null => loginScreenBuilder(context),
        };
      },
    );
  }
}
