import 'dart:async' show Timer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/app_frame.dart' show DismissKeyboardOnNav;
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/feedback.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/user/models/profile_model.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/shared/widgets/app_sidebar.dart';
import 'package:aidvise_platform/user/widgets/user_avatar.dart';
import 'package:aidvise_platform/user/screens/assessment_screen.dart';
import 'package:aidvise_platform/user/screens/resume_screen.dart';
import 'package:aidvise_platform/user/screens/profile_setup_screen.dart';
import 'package:aidvise_platform/user/screens/career_progress_screen.dart';
import 'package:aidvise_platform/user/screens/job_browse_screen.dart';
import 'package:aidvise_platform/user/screens/my_applications_screen.dart';
import 'package:aidvise_platform/user/screens/notifications_screen.dart';
import 'package:aidvise_platform/user/screens/messages_screen.dart';
import 'package:aidvise_platform/user/screens/screening_screen.dart';
import 'package:aidvise_platform/user/screens/interview_prep_screen.dart';
import 'package:aidvise_platform/user/screens/subscription_screen.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;

  /// Drives the slide-in when the tab changes, so moving between sections
  /// from the sidebar reads like navigation rather than a cut.
  late final AnimationController _tabSlide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  int _unread = 0;

  /// Tabs built so far. IndexedStack builds every child eagerly, which used
  /// to run Notifications' loader at login — marking everything read and
  /// clearing the badge before the user ever opened it. Tabs are now created
  /// on first visit and kept alive afterwards.
  final Set<int> _visited = {0};

  /// Which edge the incoming tab slides from: +1 opening a section, -1
  /// returning home, so back reverses the motion of forward.
  double _slideFrom = 1;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _homeNavKey = GlobalKey<NavigatorState>();
  final _notificationsNavKey = GlobalKey<NavigatorState>();
  final _profileNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _refreshUnread();
  }

  @override
  void dispose() {
    _tabSlide.dispose();
    super.dispose();
  }

  /// Sidebar selection: switch tab and pick up any new activity.
  void _selectTab(int index) {
    _goToTab(index);
    if (index != 2) _refreshUnread();
  }

  void _goToTab(int index) {
    if (index == _currentTab) return;
    setState(() {
      _visited.add(index);
      _slideFrom = index == 0 ? -1 : 1; // home is "back"
      _currentTab = index;
    });
    _tabSlide.forward(from: 0);
  }

  /// Placeholder until a tab is first opened, so its screen never runs its
  /// loaders (or side effects) while invisible.
  Widget _tab(int index, Widget child) =>
      _visited.contains(index) ? child : const SizedBox.shrink();

  Future<void> _refreshUnread() async {
    try {
      final count = await ApiService.getUnreadNotificationCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {} // badge is cosmetic
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute(builder: loginScreenBuilder),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navKey = switch (_currentTab) {
          0 => _homeNavKey,
          1 => _notificationsNavKey,
          _ => _profileNavKey,
        };
        if (navKey.currentState?.canPop() ?? false) {
          navKey.currentState?.pop();
        } else if (_currentTab != 0) {
          _goToTab(0); // back from a tab root goes home
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawerScrimColor: Colors.transparent,
        endDrawer: AppSidebar(items: [
          AppSidebarItem(
              icon: Icons.home, label: 'Home', onTap: () => _selectTab(0)),
          AppSidebarItem(
              icon: Icons.notifications,
              label: 'Notifications',
              badge: _unread,
              onTap: () => _selectTab(1)),
          AppSidebarItem(
              icon: Icons.person, label: 'Profile', onTap: () => _selectTab(2)),
        ]),
        body: AnimatedBuilder(
          animation: _tabSlide,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_tabSlide.value);
            return Opacity(
              opacity: t,
              child: FractionalTranslation(
                translation: Offset(0.08 * _slideFrom * (1 - t), 0),
                child: child,
              ),
            );
          },
          child: IndexedStack(
            index: _currentTab,
            children: [
              Navigator(
                key: _homeNavKey,
                observers: [DismissKeyboardOnNav()],
                onGenerateRoute: (_) => AppPageRoute(
                  builder: (_) => _HomeTab(
                    // Pushed, not a tab switch, so it slides in like every
                    // other page instead of appearing instantly.
                    openProfile: () => _homeNavKey.currentState?.push(
                      AppPageRoute(
                        builder: (_) => _ProfileTab(
                          onLogout: _logout,
                          onBack: () => _homeNavKey.currentState?.pop(),
                        ),
                      ),
                    ),
                    openSidebar: () =>
                        _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ),
              ),
              _tab(
                  1,
                  Navigator(
                    key: _notificationsNavKey,
                    observers: [DismissKeyboardOnNav()],
                    onGenerateRoute: (_) => AppPageRoute(
                      builder: (_) => NotificationsScreen(
                        onUnreadChanged: (count) => setState(() => _unread = count),
                        onBack: () => _goToTab(0),
                      ),
                    ),
                  )),
              _tab(
                  2,
                  Navigator(
                    key: _profileNavKey,
                    observers: [DismissKeyboardOnNav()],
                    onGenerateRoute: (_) => AppPageRoute(
                      builder: (_) => _ProfileTab(
                        onLogout: _logout,
                        onBack: () => _goToTab(0),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final VoidCallback openProfile;
  final VoidCallback openSidebar;
  const _HomeTab({
    required this.openProfile,
    required this.openSidebar,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  /// Applications with a pending assessment or upcoming interview.
  List<Map<String, dynamic>> _reminders = [];

  /// null until loaded — the status line is hidden meanwhile.
  bool? _assessmentDone;

  /// Rotates between plain and tailored resume counts.
  List<String> _resumeStatuses = [];
  int _resumeStatusIndex = 0;
  String? _userName;
  String? _username;
  String? _avatarUrl;

  bool _remindersOpen = true;
  bool _toolsOpen = true;

  /// Rotating status lines for the Browse Jobs / My Applications cards.
  /// Each entry carries its filter target so the chip is clickable.
  List<({String label, int? occupationId})> _jobsStatuses = [];
  int _jobsStatusIndex = 0;
  List<({String label, String? status})> _appStatuses = [];
  int _appStatusIndex = 0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _loadStatuses();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        if (_jobsStatuses.length > 1) {
          _jobsStatusIndex = (_jobsStatusIndex + 1) % _jobsStatuses.length;
        }
        if (_appStatuses.length > 1) {
          _appStatusIndex = (_appStatusIndex + 1) % _appStatuses.length;
        }
        if (_resumeStatuses.length > 1) {
          _resumeStatusIndex =
              (_resumeStatusIndex + 1) % _resumeStatuses.length;
        }
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  /// Every status line on this screen comes from one request — the server
  /// does the counting, so the page is a single round trip rather than the
  /// eight it used to take.
  Future<void> _loadStatuses({bool refresh = false}) async {
    try {
      final summary = await ApiService.getHomeSummary(refresh: refresh);
      if (!mounted) return;

      final jobs = summary['jobs'] as Map<String, dynamic>? ?? {};
      final total = (jobs['total'] as num?)?.toInt() ?? 0;
      final jobStatuses = <({String label, int? occupationId})>[
        (label: '$total job${total == 1 ? '' : 's'} available', occupationId: null),
        for (final f in (jobs['by_occupation'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>())
          (
            label: '${(f['count'] as num?)?.toInt() ?? 0} in ${f['title']}',
            occupationId: f['id'] as int?,
          ),
      ];

      final resumes = summary['resumes'] as Map<String, dynamic>? ?? {};
      final plain = (resumes['plain'] as num?)?.toInt() ?? 0;
      final tailored = (resumes['tailored'] as num?)?.toInt() ?? 0;

      final byStatus =
          (summary['applications'] as Map<String, dynamic>?)?['by_status']
                  as Map<String, dynamic>? ??
              {};
      const order = [
        'submitted',
        'reviewed',
        'shortlisted',
        'interview',
        'hired',
        'rejected'
      ];

      final user = summary['user'] as Map<String, dynamic>? ?? {};
      final fullName = (user['full_name'] as String?)?.trim();
      final username = (user['username'] as String?)?.trim();

      setState(() {
        _userName =
            (fullName?.isNotEmpty ?? false) ? fullName : username;
        _username = username;
        _avatarUrl = user['avatar_url'] as String?;
        _assessmentDone = (summary['assessment']
            as Map<String, dynamic>?)?['completed'] as bool?;
        _jobsStatuses = jobStatuses;
        _jobsStatusIndex = 0;
        _resumeStatuses = [
          '$plain Resume${plain == 1 ? '' : 's'}',
          '$tailored Tailored Resume${tailored == 1 ? '' : 's'}',
        ];
        _resumeStatusIndex = 0;
        _appStatuses = [
          for (final key in order)
            if (((byStatus[key] as num?)?.toInt() ?? 0) > 0)
              (label: '${(byStatus[key] as num).toInt()} $key', status: key),
        ];
        if (_appStatuses.isEmpty) {
          _appStatuses = [(label: 'No applications yet', status: null)];
        }
        _appStatusIndex = 0;
      });
    } catch (_) {} // statuses are a bonus — never block the home tab
  }

  Future<void> _loadReminders() async {
    try {
      final applications = await ApiService.getMyApplications();
      if (!mounted) return;
      setState(() {
        _reminders = applications
            .where((a) =>
                a['assessment_pending'] == true || a['prep_available'] == true)
            .toList();
      });
    } catch (_) {} // reminders are a bonus — never block the home tab
  }

  Future<void> _openReminder(Map<String, dynamic> application) async {
    final id = application['id'] as int;
    final pendingAssessment = application['assessment_pending'] == true;
    await Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => pendingAssessment
            ? ScreeningScreen(applicationId: id)
            : InterviewPrepScreen(applicationId: id),
      ),
    );
    _loadReminders(); // assessment may have just been submitted
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: widget.openProfile,
                  child: UserAvatar(
                      username: _username, avatarUrl: _avatarUrl, size: 52),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hello',
                        style: TextStyle(color: AppTheme.primary, fontSize: 15),
                      ),
                      Text(
                        _userName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Messages',
                  icon: const Icon(Icons.forum_outlined,
                      color: AppTheme.primary, size: 27),
                  onPressed: () => Navigator.of(context).push(
                    AppPageRoute(builder: (_) => const MessagesScreen()),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  icon:
                      const Icon(Icons.menu, color: AppTheme.primary, size: 32),
                  onPressed: widget.openSidebar,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_reminders.isNotEmpty) ...[
              _SectionHeader(
                title: 'Reminders',
                expanded: _remindersOpen,
                onTap: () => setState(() => _remindersOpen = !_remindersOpen),
              ),
              _Collapsible(
                expanded: _remindersOpen,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _RemindersSection(
                      reminders: _reminders, onOpen: _openReminder),
                ),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 8),
            _SectionHeader(
              title: 'Your career tools',
              expanded: _toolsOpen,
              onTap: () => setState(() => _toolsOpen = !_toolsOpen),
            ),
            const SizedBox(height: 14),
            _Collapsible(
              expanded: _toolsOpen,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Fixed height so all four tiles are identical whatever
                // their status text.
                childAspectRatio: 1.05,
                children: [
                  AppCard(
                    tile: true,
                    icon: Icons.psychology,
                    title: 'Career Assessment',
                    status: _assessmentDone == null
                        ? null
                        : _assessmentDone!
                            ? 'Completed'
                            : 'Pending',
                    statusIcon: _assessmentDone == true
                        ? Icons.check_circle
                        : Icons.schedule,
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppPageRoute(builder: (_) => const AssessmentScreen()),
                      );
                      _loadStatuses(refresh: true);
                    },
                  ),
                  AppCard(
                    tile: true,
                    icon: Icons.description,
                    title: 'Resume Generator',
                    status: _resumeStatuses.isEmpty
                        ? null
                        : _resumeStatuses[_resumeStatusIndex],
                    statusIcon: Icons.auto_awesome,
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppPageRoute(builder: (_) => const ResumeScreen()),
                      );
                      _loadStatuses(refresh: true);
                    },
                  ),
                  AppCard(
                    tile: true,
                    icon: Icons.work,
                    title: 'Browse Jobs',
                    status: _jobsStatuses.isEmpty
                        ? null
                        : _jobsStatuses[_jobsStatusIndex].label,
                    statusIcon: Icons.search,
                    onStatusTap: _jobsStatuses.isEmpty
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              AppPageRoute(
                                builder: (_) => JobBrowseScreen(
                                    initialOccupationId:
                                        _jobsStatuses[_jobsStatusIndex]
                                            .occupationId),
                              ),
                            );
                            _loadStatuses(refresh: true);
                          },
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppPageRoute(builder: (_) => const JobBrowseScreen()),
                      );
                      _loadStatuses(refresh: true);
                    },
                  ),
                  AppCard(
                    tile: true,
                    icon: Icons.fact_check,
                    title: 'My Applications',
                    status: _appStatuses.isEmpty
                        ? null
                        : _appStatuses[_appStatusIndex].label,
                    statusIcon: Icons.timeline,
                    onStatusTap: _appStatuses.isEmpty
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              AppPageRoute(
                                builder: (_) => MyApplicationsScreen(
                                    initialStatus:
                                        _appStatuses[_appStatusIndex].status),
                              ),
                            );
                            _loadReminders();
                          },
                    onTap: () async {
                      await Navigator.of(context).push(
                        AppPageRoute(
                            builder: (_) => const MyApplicationsScreen()),
                      );
                      _loadReminders();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable section heading with a chevron that flips when collapsed.
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;
  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: expanded ? 0 : -0.25,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down,
                color: AppTheme.primary, size: 24),
          ),
        ],
      ),
    );
  }
}

/// Animates a section open and shut.
class _Collapsible extends StatelessWidget {
  final bool expanded;
  final Widget child;
  const _Collapsible({required this.expanded, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: SizedBox(width: double.infinity, child: child),
      secondChild: const SizedBox(width: double.infinity, height: 0),
      crossFadeState:
          expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 220),
      sizeCurve: Curves.easeInOut,
    );
  }
}

/// Swipeable stack of reminder cards — one per pending assessment or
/// upcoming interview. The whole section disappears when there's nothing due.
class _RemindersSection extends StatefulWidget {
  final List<Map<String, dynamic>> reminders;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  const _RemindersSection({required this.reminders, required this.onOpen});

  @override
  State<_RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<_RemindersSection> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final reminders = widget.reminders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 172,
          child: PageView.builder(
            controller: PageController(
                viewportFraction: reminders.length > 1 ? 0.94 : 1.0),
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: reminders.length,
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(right: reminders.length > 1 ? 10 : 0),
              child: _ReminderCard(
                application: reminders[i],
                onTap: () => widget.onOpen(reminders[i]),
              ),
            ),
          ),
        ),
        if (reminders.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              reminders.length,
              (i) => Container(
                width: i == _page ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color:
                      i == _page ? AppTheme.primary : const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Map<String, dynamic> application;
  final VoidCallback onTap;
  const _ReminderCard({required this.application, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAssessment = application['assessment_pending'] == true;
    final company = (application['company'] as String? ?? '').trim();
    final interviewAt =
        _formatInterviewAt(application['interview_at'] as String?);
    final kind = isAssessment ? 'Assessment' : 'Interview';

    return AppCard(
      shell: CardShell.accent,
      icon: isAssessment ? Icons.quiz : Icons.calendar_month,
      // Which employer, so two queued reminders are tellable apart; the
      // when goes underneath.
      title: company.isEmpty ? kind : '$kind · $company',
      description: isAssessment
          ? 'Screening questions are waiting'
          : interviewAt ?? 'Time to be confirmed',
      buttonLabel:
          isAssessment ? 'Answer screening questions' : 'Review prep materials',
      onTap: onTap,
    );
  }

  /// "2026-07-20T10:00:00+08:00" → "Mon, 20 Jul · 10:00 AM"
  static String? _formatInterviewAt(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return null;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} '
        '· $hour:$minute $period';
  }
}

// ── Profile tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onBack;
  const _ProfileTab({required this.onLogout, required this.onBack});

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
                  style: TextStyle(color: Color(0xFFEF233C)))),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.primary, size: 26),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                      onAddExperience: () => Navigator.of(context).push(
                        AppPageRoute(
                            builder: (_) => const ProfileSetupScreen()),
                      ).then((_) => _loadProfile()),
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        AppPageRoute(
                            builder: (_) =>
                                const ProfileSetupScreen(isEditing: true)),
                      );
                      _loadProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Edit Profile',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => showFeedbackDialog(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Send Feedback',
                      style: TextStyle(color: AppTheme.primary, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _changePassword,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Change Password',
                      style: TextStyle(color: AppTheme.primary, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: widget.onLogout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Sign Out',
                      style: TextStyle(color: AppTheme.primary, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _deleteAccount,
                  child: const Text('Delete Account',
                      style: TextStyle(color: Color(0xFFEF233C), fontSize: 14)),
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
        color: const Color(0xFFF5F5F5),
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
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ],
      ),
    );
  }
}
