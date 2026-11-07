import 'package:flutter/material.dart';
import 'package:aidvise_platform/admin/admin_shell.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';

/// Lets a signed-in administrator into the panel. Anyone else is sent to
/// the login screen; the server enforces this on every call regardless.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late final Future<bool> _isAdmin = _resolve();

  Future<bool> _resolve() async {
    if (!await ApiService.isLoggedIn()) return false;
    try {
      final me = await ApiService.getMe(refresh: true).timeout(const Duration(seconds: 8));
      if (me['is_admin'] == true) return true;
      await ApiService.logout(notice: 'This account is not an administrator.');
    } catch (_) {
      await ApiService.logout(notice: 'Could not verify your session. Please log in again.');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        return snapshot.data == true ? const AdminShell() : loginScreenBuilder(context);
      },
    );
  }
}
