import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/shared/widgets/aidvise_wordmark.dart';
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
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: wide,
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              selectedIndex: _selected,
              onDestinationSelected: (i) => setState(() => _selected = i),
              indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
              selectedIconTheme: const IconThemeData(color: AppTheme.primary),
              selectedLabelTextStyle:
                  const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: wide
                    ? const Column(children: [
                        AidViseWordmark(fontSize: 26),
                        Text('Admin', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      ])
                    : const Icon(Icons.admin_panel_settings, color: AppTheme.primary),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: wide
                        ? TextButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout, color: AppTheme.primary),
                            label: const Text('Sign out', style: TextStyle(color: AppTheme.primary)),
                          )
                        : IconButton(
                            onPressed: _signOut,
                            tooltip: 'Sign out',
                            icon: const Icon(Icons.logout, color: AppTheme.primary)),
                  ),
                ),
              ),
              destinations: [
                for (final s in _sections)
                  NavigationRailDestination(icon: Icon(s.icon), label: Text(s.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            // Keyed so switching sections builds a fresh screen (and reloads).
            Expanded(child: KeyedSubtree(key: ValueKey(_selected), child: _sections[_selected].builder(context))),
          ],
        ),
      ),
    );
  }
}
