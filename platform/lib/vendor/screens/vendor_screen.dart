import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/vendor/pages/applicants_page.dart';
import 'package:aidvise_platform/shared/app_frame.dart'
    show DismissKeyboardOnNav;
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/feedback.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/vendor/screens/vendor_listings_screen.dart';

/// Vendor shell — same structure as the job-seeker side: a sidebar drawer,
/// tabs that slide, and the shared card system. Unapproved vendor accounts
/// can't log in, so this assumes approval.
class VendorScreen extends StatefulWidget {
  const VendorScreen({super.key});

  @override
  State<VendorScreen> createState() => _VendorScreenState();
}

enum _Area { home, listings, applicants, profile }

/// The employer's web app: the draft's sidebar shell around four areas,
/// each with its own page history.
class _VendorScreenState extends State<VendorScreen> {
  _Area _current = _Area.home;
  final Set<_Area> _visited = {_Area.home};
  final Map<_Area, GlobalKey<NavigatorState>> _navKeys = {
    for (final a in _Area.values) a: GlobalKey<NavigatorState>(),
  };

  void _open(_Area area) {
    setState(() {
      // Its own menu entry again: a fresh Navigator, back to its first page.
      if (area == _current) _navKeys[area] = GlobalKey<NavigatorState>();
      _visited.add(area);
      _current = area;
    });
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(AppPageRoute(builder: loginScreenBuilder), (_) => false);
  }

  Widget _page(_Area area) => switch (area) {
        _Area.home => _VendorHomeTab(
            openListings: () => _open(_Area.listings),
            openApplicants: () => _open(_Area.applicants),
            openProfile: () => _open(_Area.profile),
          ),
        _Area.listings => const VendorListingsScreen(),
        _Area.applicants => ApplicantsPage(onPostJob: () => _open(_Area.listings)),
        _Area.profile => _VendorProfileTab(onLogout: _logout),
      };

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.work_outline, 'Listings'),
      (Icons.people_outline, 'Applicants'),
      (Icons.person_outline, 'Profile'),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKeys[_current]!.currentState;
        if (nav?.canPop() ?? false) {
          nav!.pop();
        } else if (_current != _Area.home) {
          _open(_Area.home);
        }
      },
      child: Scaffold(
        backgroundColor: Ui.bg,
        body: UiShell(
          selected: _current.index,
          items: [
            for (final a in _Area.values)
              UiNavItem(icon: items[a.index].$1, label: items[a.index].$2, onTap: () => _open(a)),
          ],
          child: IndexedStack(
            index: _current.index,
            children: [
              for (final a in _Area.values)
                _visited.contains(a)
                    ? Navigator(
                        key: _navKeys[a],
                        observers: [DismissKeyboardOnNav()],
                        onGenerateRoute: (_) => AppPageRoute(builder: (_) => _page(a)),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorHomeTab extends StatefulWidget {
  final VoidCallback openListings;
  final VoidCallback openApplicants;
  final VoidCallback openProfile;
  const _VendorHomeTab(
      {required this.openListings, required this.openApplicants, required this.openProfile});

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

  /// Draft "Sidebar dashboard", employer edition: greeting, tool tiles,
  /// and what being approved means.
  @override
  Widget build(BuildContext context) {
    final name = _companyName ?? 'your company';
    final tiles = [
      (Icons.work_outline, 'Listings', _listingCount == 1 ? '1 listing' : '$_listingCount listings',
          Tone.brand, widget.openListings),
      (Icons.people_outline, 'Applicants', '$_applicantCount total', Tone.plain, widget.openApplicants),
      (Icons.mark_email_unread_outlined, 'To review', '$_pendingReview awaiting review',
          _pendingReview > 0 ? Tone.warn : Tone.good, widget.openApplicants),
      (Icons.person_outline, 'Profile', 'Company and account', Tone.plain, widget.openProfile),
    ];
    return UiState(
      loading: _loading,
      builder: () => UiPage(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(longToday()),
              Text('${greeting()}, $name', style: Ui.display(Ui.step3)),
            ]),
          ),
          Clickable(
            onTap: widget.openProfile,
            child: UiAvatar(name, background: Ui.steel, foreground: Colors.white),
          ),
        ]),
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth < 520 ? 1 : box.maxWidth < 760 ? 2 : 4;
          final width = (box.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final (icon, title, status, tone, onTap) in tiles)
              SizedBox(
                width: width,
                child: Panel(
                  onTap: onTap,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconTile(icon),
                    const SizedBox(height: 14),
                    Text(title.toUpperCase(),
                        style: Ui.body(weight: FontWeight.w800, color: Ui.brand)
                            .copyWith(letterSpacing: 0.06 * Ui.step0)),
                    const SizedBox(height: 14),
                    Pill(status, tone: tone),
                  ]),
                ),
              ),
          ]);
        }),
        Panel(
          child: Row(children: [
            const IconTile(Icons.verified_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Approved employer', style: Ui.body(weight: FontWeight.w700)),
                Text('Your live listings appear to job seekers whose assessment matches the job\'s field.',
                    style: Ui.meta),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Profile tab ──────────────────────────────────────────────────────────────

class _VendorProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  const _VendorProfileTab({required this.onLogout});

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
              height: 44,
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
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Ui.bad,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Ui.bad),
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
