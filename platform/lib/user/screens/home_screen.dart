
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/user/pages/sections.dart';
import 'package:aidvise_platform/user/pages/home_page.dart';
import 'package:aidvise_platform/user/pages/jobs_page.dart';
import 'package:aidvise_platform/user/pages/applications_page.dart';
import 'package:aidvise_platform/user/pages/resumes_page.dart';
import 'package:aidvise_platform/user/pages/assessment_page.dart';
import 'package:aidvise_platform/user/pages/notifications_page.dart';
import 'package:aidvise_platform/shared/app_frame.dart'
    show DismissKeyboardOnNav;
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/feedback.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/user/models/profile_model.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/user/widgets/user_avatar.dart';
import 'package:aidvise_platform/user/screens/profile_setup_screen.dart';
import 'package:aidvise_platform/user/screens/career_progress_screen.dart';
import 'package:aidvise_platform/user/screens/subscription_screen.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// The job seeker's web app: the draft's sidebar shell around seven areas.
/// Each area keeps its own page history, so opening a screening test or a
/// resume keeps the sidebar in place and coming back returns to the list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserSection _current = UserSection.home;
  final Set<UserSection> _visited = {UserSection.home};
  final Map<UserSection, GlobalKey<NavigatorState>> _navKeys = {
    for (final s in UserSection.values) s: GlobalKey<NavigatorState>(),
  };

  /// Preselection passed when opening an area (e.g. a job id).
  final Map<UserSection, Object?> _args = {};
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  Future<void> _refreshUnread() async {
    try {
      final count = await ApiService.getUnreadNotificationCount(refresh: true);
      if (mounted) setState(() => _unread = count);
    } catch (_) {} // the badge is cosmetic
  }

  void _open(UserSection section, {Object? arg}) {
    setState(() {
      if (arg != null || section == _current) {
        // A new preselection, or the current area's menu entry again:
        // start the area afresh at its first page.
        _args[section] = arg;
        // A new key gives the area a fresh Navigator (and first page).
        _navKeys[section] = GlobalKey<NavigatorState>();
      }
      _visited.add(section);
      _current = section;
    });
    if (section != UserSection.notifications) _refreshUnread();
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(AppPageRoute(builder: loginScreenBuilder), (_) => false);
  }

  Widget _page(UserSection section) => switch (section) {
        UserSection.home => HomePage(open: _open),
        UserSection.jobs => JobsPage(initialJobId: _args[UserSection.jobs] as int?),
        UserSection.applications => ApplicationsPage(open: _open),
        UserSection.resumes => const ResumesPage(),
        UserSection.assessment => const AssessmentPage(),
        UserSection.notifications => NotificationsPage(
            open: _open, onUnreadChanged: (n) => setState(() => _unread = n)),
        UserSection.profile => _ProfileTab(onLogout: _logout),
      };

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.work_outline, 'Jobs'),
      (Icons.fact_check_outlined, 'Applications'),
      (Icons.description_outlined, 'Resumes'),
      (Icons.explore_outlined, 'Assessment'),
      (Icons.notifications_none, 'Notifications'),
      (Icons.person_outline, 'Profile'),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[_current]!.currentState;
        if (nav?.canPop() ?? false) {
          nav!.pop();
        } else if (_current != UserSection.home) {
          _open(UserSection.home);
        }
      },
      child: Scaffold(
        backgroundColor: Ui.bg,
        body: UiShell(
          selected: _current.index,
          items: [
            for (final s in UserSection.values)
              UiNavItem(
                icon: items[s.index].$1,
                label: items[s.index].$2,
                badge: s == UserSection.notifications ? _unread : 0,
                onTap: () => _open(s),
              ),
          ],
          child: IndexedStack(
            index: _current.index,
            children: [
              for (final s in UserSection.values)
                _visited.contains(s)
                    ? Navigator(
                        key: _navKeys[s],
                        observers: [DismissKeyboardOnNav()],
                        onGenerateRoute: (_) => AppPageRoute(builder: (_) => _page(s)),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;

  const _ProfileTab({required this.onLogout});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  ProfileModel? _profile;
  Map<String, dynamic>? _me; // plan + quota usage
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool refresh = false}) async {
    if (!mounted) return;
    if (!refresh) setState(() => _loading = true);
    try {
      final me = await ApiService.getMe(refresh: refresh);
      if (mounted) setState(() => _me = me);
    } catch (_) {}
    try {
      final data = await ApiService.getProfile(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _profile = ProfileModel.fromJson(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Pick and upload a new profile picture. Limits mirror the server's
  /// (PNG/JPEG, 2 MB) so the user hears about a bad file before the upload.
  Future<void> _changeAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true, // web gives bytes, never a path
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;

    final size = result!.files.single.size;
    if (size > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image too large (max 2 MB)')),
      );
      return;
    }

    try {
      await ApiService.uploadAvatar(
          bytes: bytes, fileName: result.files.single.name);
      if (!mounted) return;
      await _loadProfile(refresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password')),
            TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'New password (min 8 characters)')),
            TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Update')),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    if (newCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match')));
      return;
    }
    try {
      await ApiService.changePassword(
          currentPassword: currentCtrl.text, newPassword: newCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password updated')));
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This permanently deletes your account, profile, resumes, and '
            'job applications. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: Ui.bad))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteAccount(); // also clears token + cache
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        AppPageRoute(builder: loginScreenBuilder),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _buildPlanCard() {
    final me = _me;
    if (me == null) return const SizedBox.shrink();
    final label = me['tier_label'] as String? ?? 'Free';
    final limits = me['limits'] as Map<String, dynamic>? ?? {};
    final chat = limits['chat_messages_per_day'] as Map<String, dynamic>?;
    final gens =
        limits['resume_generations_per_month'] as Map<String, dynamic>?;

    CardDetail? quotaRow(Map<String, dynamic>? q, IconData icon, String label) {
      if (q == null) return null;
      final limit = q['limit'];
      return CardDetail(
        icon,
        limit == null ? '$label: unlimited' : '$label: ${q['used']}/$limit',
      );
    }

    final quotas = [
      quotaRow(
          gens, Icons.description_outlined, 'Resume generations this month'),
      quotaRow(chat, Icons.chat_bubble_outline, 'Advisor chats today'),
    ].whereType<CardDetail>().toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        icon: Icons.workspace_premium,
        title: '$label Plan',
        details: quotas.isNotEmpty ? quotas : null,
        description: quotas.isEmpty ? 'Tap to manage your subscription.' : null,
        onTap: () async {
          await Navigator.of(context).push(
            AppPageRoute(builder: (_) => const SubscriptionScreen()),
          );
          _loadProfile(); // tier may have changed
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _loadProfile(refresh: true),
        color: AppTheme.primary,
        child: SingleChildScrollView(
          // Always scrollable so the pull-to-refresh gesture works even when
          // the content fits on screen.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContentHead(
                eyebrow: 'Your account',
                title: 'Profile',
                actions: [
                  if (_profile != null)
                    UiButton('Edit profile', onPressed: () async {
                      await Navigator.of(context).push(AppPageRoute(
                          builder: (_) => const ProfileSetupScreen(isEditing: true)));
                      _loadProfile();
                    }),
                  UiButton.ghost('Send feedback', onPressed: () => showFeedbackDialog(context)),
                  UiButton.ghost('Change password', onPressed: _changePassword),
                  UiButton.ghost('Sign out', onPressed: widget.onLogout),
                ],
              ),
              const SizedBox(height: 20),
              _buildPlanCard(),
              AppCard(
                icon: Icons.trending_up,
                title: 'Career Progress',
                description:
                    'Your experience, how it lines up with your assessment, '
                    'and the milestones you have reached.',
                status: 'Private to you',
                statusIcon: Icons.lock_outline,
                onTap: () => Navigator.of(context).push(
                  AppPageRoute(
                    builder: (_) => CareerProgressScreen(
                      onAddExperience: () => Navigator.of(context)
                          .push(
                            AppPageRoute(
                                builder: (_) => const ProfileSetupScreen()),
                          )
                          .then((_) => _loadProfile()),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_profile == null) ...[
                AppCard(
                  icon: Icons.person_add_alt_1,
                  title: 'No profile yet',
                  description:
                      'Set up your profile to generate a tailored resume.',
                  status: 'Create profile',
                  statusIcon: Icons.arrow_forward,
                  onTap: () async {
                    await Navigator.of(context).push(
                      AppPageRoute(builder: (_) => const ProfileSetupScreen()),
                    );
                    _loadProfile();
                  },
                ),
              ] else ...[
                AppCard(
                  image: GestureDetector(
                    onTap: _changeAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        UserAvatar(
                          username: _me?['username'] as String?,
                          avatarUrl: _profile?.avatarUrl,
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: AppTheme.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.photo_camera,
                              size: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  title: _profile!.name ?? 'No name',
                  details: [
                    if ((_profile!.email ?? '').isNotEmpty)
                      CardDetail(Icons.email_outlined, _profile!.email!),
                    if ((_profile!.phone ?? '').isNotEmpty)
                      CardDetail(Icons.phone_outlined, _profile!.phone!),
                    if ((_profile!.linkedin ?? '').isNotEmpty)
                      CardDetail(Icons.link, _profile!.linkedin!),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _StatCard(
                            label: 'Experiences',
                            count: _profile!.experiences.length)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Skills', count: _profile!.skills.length)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatCard(
                            label: 'Education',
                            count: _profile!.education.length)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _deleteAccount,
                  child: const Text('Delete Account',
                      style: TextStyle(color: Ui.bad, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  const _StatCard({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Ui.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Ui.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
