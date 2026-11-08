import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/admin/failed_jobs_screen.dart';
import 'package:aidvise_platform/admin/listings_screen.dart';
import 'package:aidvise_platform/admin/vendor_approvals_screen.dart';
import 'package:aidvise_platform/admin/plans_screen.dart';
import 'package:aidvise_platform/admin/users_screen.dart';

/// The admin panel: a side rail of sections, each a self-contained screen.
/// New sections are one entry in [_sections].
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminSection {
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
  const _AdminSection(this.icon, this.label, this.builder);
}

class _AdminShellState extends State<AdminShell> {
  static final _sections = [
    _AdminSection(Icons.people_outline, 'Users', (_) => const AdminUsersScreen()),
    _AdminSection(Icons.work_outline, 'Job Listings', (_) => const AdminListingsScreen()),
    _AdminSection(Icons.workspace_premium_outlined, 'Plans', (_) => const AdminPlansScreen()),
    _AdminSection(Icons.how_to_reg_outlined, 'Vendor Approvals', (_) => const AdminManageScreen()),
    _AdminSection(Icons.error_outline, 'Failed Resumes', (_) => const AdminJobsScreen()),
  ];

  int _selected = 0;

  Future<void> _signOut() async {
    await ApiService.logout();
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      AppPageRoute(builder: loginScreenBuilder),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ui.bg,
      body: UiShell(
        selected: _selected,
        items: [
          for (var i = 0; i < _sections.length; i++)
            UiNavItem(
              icon: _sections[i].icon,
              label: _sections[i].label,
              onTap: () => setState(() => _selected = i),
            ),
          UiNavItem(icon: Icons.logout, label: 'Sign out', onTap: _signOut),
        ],
        // Keyed so switching sections builds a fresh screen (and reloads).
        child: KeyedSubtree(key: ValueKey(_selected), child: _sections[_selected].builder(context)),
      ),
    );
  }
}
