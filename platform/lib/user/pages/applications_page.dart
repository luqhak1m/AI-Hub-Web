import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/user/pages/jobs_page.dart';
import 'package:aidvise_platform/user/pages/sections.dart';
import 'package:aidvise_platform/user/screens/interview_prep_screen.dart';
import 'package:aidvise_platform/user/screens/screening_screen.dart';

/// My applications — draft "Pipeline board": one column per review stage,
/// so where an application sits is its status.
class ApplicationsPage extends StatefulWidget {
  final OpenSection open;
  const ApplicationsPage({super.key, required this.open});

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  static const _stages = [
    ('submitted', 'Submitted'),
    ('reviewed', 'Reviewed'),
    ('shortlisted', 'Shortlisted'),
    ('interview', 'Interview'),
    ('hired', 'Hired'),
    ('rejected', 'Not selected'),
  ];

  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final apps = await ApiService.getMyApplications(refresh: true);
      if (mounted) setState(() { _apps = apps; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your applications.'; _loading = false; });
    }
  }

  int get _needsAction => _apps.where((a) => a['assessment_pending'] == true).length;
  int get _active => _apps.where((a) => !const {'hired', 'rejected'}.contains(a['status'])).length;

  @override
  Widget build(BuildContext context) {
    return UiPage(fill: true, children: [
      ContentHead(
        eyebrow: _loading ? null : '$_active active · $_needsAction ${_needsAction == 1 ? 'needs' : 'need'} your action',
        title: 'My applications',
        actions: [UiButton('Find more jobs', onPressed: () => widget.open(UserSection.jobs))],
      ),
      Expanded(
        child: UiState(
          loading: _loading,
          error: _error,
          onRetry: _load,
          empty: _apps.isEmpty,
          emptyText: 'No applications yet. Apply to a job and it appears here.',
          builder: () => UiBoard(columns: [
            for (final (status, label) in _stages)
              UiBoardColumn(label, [
                for (final a in _apps.where((a) => (a['status'] ?? 'submitted') == status)) _card(a),
              ], emptyText: status == 'hired' ? 'Offers land in this column.' : 'Nothing here yet.'),
          ]),
        ),
      ),
    ]);
  }

  // `.e-card`
  Widget _card(Map<String, dynamic> a) {
    final interview = a['status'] == 'interview';
    final action = a['assessment_pending'] == true;
    final prep = a['prep_available'] == true;
    return Panel(
      padding: const EdgeInsets.all(12),
      radius: 12,
      borderColor: interview ? context.ui.accent : null,
      onTap: () => _showActions(a),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a['job_title'] as String? ?? '', style: context.ui.body(weight: FontWeight.w700)),
        Text(a['company'] as String? ?? '', style: context.ui.meta),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (action) const Pill('Action needed', tone: Tone.warn),
          if (prep) const Pill('Prep pack ready', tone: Tone.good),
          Text(_note(a), style: context.ui.meta),
        ]),
      ]),
    );
  }

  String _note(Map<String, dynamic> a) {
    if (a['interview_at'] != null) return shortDate(a['interview_at'] as String?);
    if (a['assessment_pending'] == true) return 'Screening test waiting';
    return 'Applied ${shortDate(a['applied_at'] as String?)}';
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(AppPageRoute(builder: (_) => screen));
    _load();
  }

  /// One application's actions, in a draft-styled panel.
  Future<void> _showActions(Map<String, dynamic> a) async {
    final id = a['id'] as int;
    final stage = _stages.where((s) => s.$1 == a['status']).firstOrNull?.$2 ?? 'Submitted';
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: context.ui.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.radius)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                LogoTile(a['company'] as String? ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['job_title'] as String? ?? '', style: context.ui.display(Ui.step2)),
                    Text(a['company'] as String? ?? '', style: context.ui.meta),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                Pill(stage, tone: Tone.brand),
                Text(_note(a), style: context.ui.meta),
              ]),
              if (a['has_resume'] != true) ...[
                const SizedBox(height: 10),
                Text('No resume attached. A resume strengthens this application.', style: context.ui.meta),
              ],
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (a['assessment_pending'] == true)
                  UiButton('Start screening test', onPressed: () => Navigator.pop(dialogContext, 'screening')),
                if (a['prep_available'] == true)
                  UiButton('Open prep pack', onPressed: () => Navigator.pop(dialogContext, 'prep')),
                if (a['listing_id'] != null)
                  UiButton.ghost('View job', onPressed: () => Navigator.pop(dialogContext, 'job')),
                UiButton.ghost('Withdraw', onPressed: () => Navigator.pop(dialogContext, 'withdraw')),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'screening':
        await _push(ScreeningScreen(applicationId: id));
      case 'prep':
        await _push(InterviewPrepScreen(applicationId: id));
      case 'job':
        final job = await ApiService.getJobListing(a['listing_id'] as int);
        if (mounted) await openDetailPage(context, job['title'] as String? ?? 'Job', JobDetail(job: job));
      case 'withdraw':
        await _withdraw(a);
    }
  }

  Future<void> _withdraw(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.ui.surface,
        title: Text('Withdraw application?', style: context.ui.display(Ui.step2)),
        content: Text('Your application for ${a['job_title']} at ${a['company']} will be removed.',
            style: context.ui.body()),
        actions: [
          UiButton.ghost('Keep it', onPressed: () => Navigator.pop(dialogContext, false)),
          UiButton('Withdraw', onPressed: () => Navigator.pop(dialogContext, true)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.withdrawApplication(a['id'] as int);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
