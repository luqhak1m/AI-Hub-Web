import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/app_frame.dart' show DismissKeyboardOnNav;
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/feedback.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/shared/widgets/app_sidebar.dart';
import 'package:aidvise_platform/vendor/screens/vendor_listings_screen.dart';
import 'package:aidvise_platform/vendor/screens/vendor_applicants_screen.dart';

/// Vendor shell — same structure as the job-seeker side: a sidebar drawer,
/// tabs that slide, and the shared card system. Unapproved vendor accounts
/// can't log in, so this assumes approval.
class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

class _VendorScreenState extends State<VendorScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;

  /// Tabs are built on first visit, so a hidden screen never runs its loaders.
  final Set<int> _visited = {0};

  /// Which edge the incoming tab slides from: +1 opening a section, -1
  /// returning home, so back reverses the motion of forward.
  double _slideFrom = 1;

  late final AnimationController _tabSlide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _homeNavKey = GlobalKey<NavigatorState>();
  final _profileNavKey = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _tabSlide.dispose();
    super.dispose();
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

  Widget _tab(int index, Widget child) =>
      _visited.contains(index) ? child : const SizedBox.shrink();

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      AppPageRoute(builder: loginScreenBuilder),
      (_) => false,
    );
  }

  void _push(Widget screen) =>
      _homeNavKey.currentState?.push(AppPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final navKey = _currentTab == 0 ? _homeNavKey : _profileNavKey;
        if (navKey.currentState?.canPop() ?? false) {
          navKey.currentState?.pop();
        } else if (_currentTab != 0) {
          _goToTab(0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawerScrimColor: Colors.transparent,
        endDrawer: AppSidebar(items: [
          AppSidebarItem(
              icon: Icons.home, label: 'Home', onTap: () => _goToTab(0)),
          AppSidebarItem(
              icon: Icons.work,
              label: 'Listings',
              onTap: () {
                _goToTab(0);
                _push(const VendorListingsScreen());
              }),
          AppSidebarItem(
              icon: Icons.people,
              label: 'Applicants',
              onTap: () {
                _goToTab(0);
                _push(const VendorApplicantsScreen());
              }),
          AppSidebarItem(
              icon: Icons.person, label: 'Profile', onTap: () => _goToTab(1)),
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
                  builder: (_) => _VendorHomeTab(
                    openSidebar: () =>
                        _scaffoldKey.currentState?.openEndDrawer(),
                    openProfile: () => _homeNavKey.currentState?.push(
                      AppPageRoute(
                        builder: (_) => _VendorProfileTab(
                          onLogout: _logout,
                          onBack: () => _homeNavKey.currentState?.pop(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _tab(
                1,
                Navigator(
                  key: _profileNavKey,
                  observers: [DismissKeyboardOnNav()],
                  onGenerateRoute: (_) => AppPageRoute(
                    builder: (_) => _VendorProfileTab(
                      onLogout: _logout,
                      onBack: () => _goToTab(0),
                    ),
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

// ── Home tab ─────────────────────────────────────────────────────────────────

class _VendorHomeTab extends StatefulWidget {
  final VoidCallback openSidebar;
  final VoidCallback openProfile;
  const _VendorHomeTab({required this.openSidebar, required this.openProfile});

  @override
  State<_VendorHomeTab> createState() => _VendorHomeTabState();
}

class _VendorHomeTabState extends State<_VendorHomeTab> {
  bool _loading = true;
  String? _companyName;
  int _listingCount = 0;
  int _applicantCount = 0;
  int _pendingReview = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final me = await ApiService.getVendorStatus();
      final listings = await ApiService.getVendorListings();
      final applications = await ApiService.getVendorApplications();
      if (!mounted) return;
      setState(() {
        _companyName = me['company_name'] as String?;
        _listingCount = listings.length;
        _applicantCount = applications.length;
        _pendingReview =
            applications.where((a) => a['status'] == 'submitted').length;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(AppPageRoute(builder: (_) => screen));
    _load(); // counts may have changed
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.openProfile,
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              color: AppTheme.primary, shape: BoxShape.circle),
                          child: Text(
                            (_companyName?.isNotEmpty == true
                                    ? _companyName!.substring(0, 1)
                                    : 'V')
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hello',
                                style: TextStyle(
                                    color: AppTheme.primary, fontSize: 15)),
                            Text(
                              _companyName ?? 'Vendor Workspace',
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
                        icon: const Icon(Icons.menu,
                            color: AppTheme.primary, size: 32),
                        onPressed: widget.openSidebar,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your workspace',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.05,
                    children: [
                      AppCard(
                        tile: true,
                        icon: Icons.work,
                        title: 'Listings',
                        status: _listingCount == 1
                            ? '1 listing'
                            : '$_listingCount listings',
                        statusIcon: Icons.post_add,
                        onTap: () => _open(const VendorListingsScreen()),
                      ),
                      AppCard(
                        tile: true,
                        icon: Icons.people,
                        title: 'Applicants',
                        status: _pendingReview > 0
                            ? '$_pendingReview awaiting review'
                            : '$_applicantCount total',
                        statusIcon: Icons.fact_check,
                        onTap: () => _open(const VendorApplicantsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const AppCard(
                    icon: Icons.verified,
                    title: 'Approved vendor',
                    description:
                        'Your listings appear in the job recommendations of '
                        "users whose assessment matches the job's career "
                        'family.',
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Profile tab ──────────────────────────────────────────────────────────────

class _VendorProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onBack;
  const _VendorProfileTab({required this.onLogout, required this.onBack});

  @override
  State<_VendorProfileTab> createState() => _VendorProfileTabState();
}

class _VendorProfileTabState extends State<_VendorProfileTab> {
  bool _loading = true;
  String? _companyName;
  String? _username;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vendor = await ApiService.getVendorStatus();
      final me = await ApiService.getMe();
      if (!mounted) return;
      setState(() {
        _companyName = vendor['company_name'] as String?;
        _username = me['username'] as String?;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    return SafeArea(
      child: SingleChildScrollView(
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
            AppCard(
              title: _companyName ?? 'Vendor',
              inlineTag: 'VENDOR ACCOUNT',
              details: [
                if ((_username ?? '').isNotEmpty)
                  CardDetail(Icons.alternate_email, _username!),
              ],
            ),
            const SizedBox(height: 14),
            const AppCard(
              icon: Icons.info_outline,
              title: 'Company details',
              description:
                  'Need to update your company name or details? Contact the '
                  'AidVise team — vendor account changes are reviewed '
                  'manually.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => showFeedbackDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Send Feedback',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF233C),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFEF233C)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
