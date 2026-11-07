import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/widgets/application_dashboard.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/user/screens/screening_screen.dart';
import 'package:aidvise_platform/user/screens/interview_prep_screen.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/user/widgets/job_details_sheet.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// User dashboard for job applications: every job they've applied to,
/// its review status, and the option to withdraw.
class MyApplicationsScreen extends StatefulWidget {
  /// Preselects the status filter and opens the Applications tab
  /// (e.g. from the rotating home status chip).
  final String? initialStatus;
  const MyApplicationsScreen({super.key, this.initialStatus});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen>
    with SingleTickerProviderStateMixin {
  static const _statusLabels = {
    'submitted': 'Submitted',
    'reviewed': 'Reviewed',
    'shortlisted': 'Shortlisted',
    'interview': 'Interview',
    'hired': 'Hired',
    'rejected': 'Not selected',
  };
  static const _statusIcons = {
    'submitted': Icons.schedule,
    'reviewed': Icons.visibility_outlined,
    'shortlisted': Icons.star_outline,
    'interview': Icons.event_available,
    'hired': Icons.check_circle_outline,
    'rejected': Icons.cancel_outlined,
  };

  late final TabController _tabs;
  List<Map<String, dynamic>> _applications = [];
  String? _statusFilter; // null = all
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus;
    _tabs = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialStatus != null ? 1 : 0);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh) setState(() { _loading = true; _error = null; });
    try {
      final applications = await ApiService.getMyApplications(refresh: refresh);
      setState(() { _applications = applications; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your applications.'; _loading = false; });
    }
  }

  Future<void> _withdraw(Map<String, dynamic> application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: Text('Withdraw your application for "${application['job_title']}" '
            'at ${application['company']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF233C), foregroundColor: Colors.white),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.withdrawApplication(application['id'] as int);
      _load();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Applications', style: TextStyle(color: AppTheme.primary)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: const Color(0xFF888888),
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Dashboard'),
            Tab(text: 'Applications (${_applications.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : _applications.isEmpty
                  ? _buildEmpty()
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          color: AppTheme.primary,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ApplicationDashboard(applications: _applications),
                            ],
                          ),
                        ),
                        _buildApplicationsTab(),
                      ],
                    ),
    );
  }

  Widget _buildApplicationsTab() {
    final filtered = _statusFilter == null
        ? _applications
        : _applications
            .where((a) =>
                (a['status'] as String? ?? 'submitted') == _statusFilter)
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', null),
                for (final e in _statusLabels.entries)
                  _filterChip(e.value, e.key),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            color: AppTheme.primary,
            child: filtered.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('No applications with this status.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF888888), fontSize: 13)),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: filtered.map(_buildCard).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color:
                    selected ? AppTheme.primary : const Color(0xFFDDDDDD)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppTheme.primary,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_outline, size: 40, color: Color(0xFFCCCCCC)),
              SizedBox(height: 12),
              Text('No applications yet.',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
              SizedBox(height: 6),
              Text('Apply to jobs from Browse Jobs or your matched jobs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _buildCard(Map<String, dynamic> application) {
    final title = application['job_title'] as String? ?? '';
    final company = application['company'] as String? ?? '';
    final status = application['status'] as String? ?? 'submitted';
    final appliedAt = _formatDate(application['applied_at'] as String?);
    final hasResume = application['has_resume'] == true;
    final listingId = application['listing_id'] as int?;

    final description = [
      company,
      if (!hasResume)
        'No resume attached — generate one to strengthen this application.',
      if (application['assessment_submitted'] == true)
        'Screening assessment submitted',
    ].join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        compact: true,
        icon: Icons.work_outline,
        title: title,
        titleMeta: appliedAt,
        description: description,
        status: _statusLabels[status] ?? 'Submitted',
        statusIcon: _statusIcons[status],
        onTap: listingId == null
            ? null
            : () => showJobDetailsSheetById(context, listingId),
        actions: [
          if (application['assessment_pending'] == true)
            _smallAction(
              icon: Icons.quiz_outlined,
              label: 'Assessment',
              onPressed: () async {
                final done = await Navigator.of(context).push<bool>(
                  AppPageRoute(
                    builder: (_) => ScreeningScreen(
                        applicationId: application['id'] as int),
                  ),
                );
                if (done == true) _load();
              },
            ),
          if (application['prep_available'] == true)
            _smallAction(
              icon: Icons.school_outlined,
              label: 'Prepare for Interview',
              onPressed: () => Navigator.of(context).push(
                AppPageRoute(
                  builder: (_) => InterviewPrepScreen(
                      applicationId: application['id'] as int),
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline,
                size: 20, color: Color(0xFFEF233C)),
            tooltip: 'Withdraw',
            onPressed: () => _withdraw(application),
          ),
        ],
      ),
    );
  }

  Widget _smallAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 34,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 14),
        label: Text(label,
            style:
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  static String? _formatDate(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
