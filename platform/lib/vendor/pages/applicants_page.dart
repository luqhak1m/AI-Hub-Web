import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/screens/pdf_viewer_screen.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Employer applicants — draft "Data table": totals, then every applicant
/// with their score, skills matched and status, sortable and filterable.
class ApplicantsPage extends StatefulWidget {
  final VoidCallback onPostJob;
  const ApplicantsPage({super.key, required this.onPostJob});

  @override
  State<ApplicantsPage> createState() => _ApplicantsPageState();
}

class _ApplicantsPageState extends State<ApplicantsPage> {
  static const _statuses = {
    'submitted': ('Submitted', Tone.plain),
    'reviewed': ('Reviewed', Tone.brand),
    'shortlisted': ('Shortlisted', Tone.warn),
    'interview': ('Interview', Tone.good),
    'hired': ('Hired', Tone.good),
    'rejected': ('Not selected', Tone.bad),
  };
  static const _sorts = ['Score', 'Newest', 'Status'];

  List<Map<String, dynamic>> _apps = [];
  String? _company;
  String _query = '';
  String? _status; // null = all
  int _sort = 0;
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
      final results = await Future.wait([ApiService.getVendorApplications(), ApiService.getVendorStatus()]);
      if (!mounted) return;
      setState(() {
        _apps = (results[0] as List).cast<Map<String, dynamic>>();
        _company = (results[1] as Map)['company_name'] as String?;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load applicants.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _rows {
    final rows = _apps.where((a) {
      if (_status != null && a['status'] != _status) return false;
      if (_query.isEmpty) return true;
      return '${a['applicant_name']} ${a['job_title']}'.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    int newest(Map a, Map b) => (b['id'] as int).compareTo(a['id'] as int);
    switch (_sorts[_sort]) {
      case 'Score':
        rows.sort((a, b) => ((b['score'] as num?) ?? -1).compareTo((a['score'] as num?) ?? -1));
      case 'Newest':
        rows.sort(newest);
      case 'Status':
        final order = _statuses.keys.toList();
        rows.sort((a, b) => order.indexOf(a['status'] as String).compareTo(order.indexOf(b['status'] as String)));
    }
    return rows;
  }

  /// "2 of 5" from the skills component, or "—" when the listing sets none.
  static String _skills(Map<String, dynamic> a) {
    final detail = ((a['score_breakdown'] as Map?)?['skills'] as Map?)?['detail'] as String? ?? '';
    return RegExp(r'^\d+ of \d+').firstMatch(detail)?.group(0) ?? '—';
  }

  Future<void> _setStatus(Map<String, dynamic> a, String status) async {
    try {
      await ApiService.setApplicationStatus(a['id'] as int, status);
      setState(() => a['status'] = status);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openResume(Map<String, dynamic> a) async {
    await Navigator.of(context).push(AppPageRoute(
      builder: (_) => PdfViewerScreen(
        title: 'Applicant resume',
        pdfPath: ApiService.applicantResumePath(a['id'] as int),
        downloadName: 'applicant_resume_${a['id']}',
      ),
    ));
    _load(); // opening the resume marks it reviewed
  }

  @override
  Widget build(BuildContext context) {
    final scores = _apps.map((a) => a['score'] as num?).whereType<num>().toList();
    final avg = scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length;
    final rows = _rows;
    final requests = _apps.where((a) => a['reschedule_request'] != null).toList();

    return UiState(
      loading: _loading,
      error: _error,
      onRetry: _load,
      builder: () => UiPage(children: [
        ContentHead(
          eyebrow: '${_company ?? 'Employer'} · ${_apps.length} applicants · sorted by ${_sorts[_sort].toLowerCase()}',
          title: 'Applicants',
          titleSize: Ui.step2,
          actions: [
            SizedBox(
              width: 220,
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: context.ui.body(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search applicants',
                  hintStyle: context.ui.body(color: context.ui.muted),
                  filled: true,
                  fillColor: context.ui.surface,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.line)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ui.radiusSm)),
                ),
              ),
            ),
            PopupMenuButton<String?>(
              tooltip: 'Filter by status',
              onSelected: (v) => setState(() => _status = v == 'all' ? null : v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'all', child: Text('All')),
                for (final e in _statuses.entries) PopupMenuItem(value: e.key, child: Text(e.value.$1)),
              ],
              child: UiChip('Status: ${_status == null ? 'All' : _statuses[_status]!.$1}'),
            ),
            UiChip('Sort: ${_sorts[_sort]}', onTap: () => setState(() => _sort = (_sort + 1) % _sorts.length)),
            UiButton('Post a job', onPressed: widget.onPostJob),
          ],
        ),
        StatsRow([
          ('Applicants', '${_apps.length}'),
          ('Average score', avg == null ? '—' : '${avg.round()}'),
          ('Shortlisted', '${_apps.where((a) => a['status'] == 'shortlisted').length}'),
          ('Interviews', '${_apps.where((a) => a['status'] == 'interview').length}'),
        ]),
        for (final a in requests) _rescheduleBanner(a),
        if (rows.isEmpty)
          Panel(child: Text(_apps.isEmpty ? 'No applicants yet.' : 'No applicants match.', style: context.ui.body(color: context.ui.muted)))
        else
          UiTable(
            columns: const ['Applicant', 'Score', 'Skills matched', 'Job', 'Status', 'Applied', ''],
            rows: [
              for (final a in rows)
                UiTableRow(
                  [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      UiAvatar(a['applicant_name'] as String? ?? '', size: 28),
                      const SizedBox(width: 10),
                      Text(a['applicant_name'] as String? ?? '', style: context.ui.body(weight: FontWeight.w600)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 32,
                        child: Text(a['score'] == null ? '—' : '${(a['score'] as num).round()}',
                            style: context.ui.body().copyWith(fontFeatures: Ui.tabular)),
                      ),
                      ScoreBar(((a['score'] as num?) ?? 0) / 100, width: 70),
                    ]),
                    Text(_skills(a), style: context.ui.body().copyWith(fontFeatures: Ui.tabular)),
                    Text(a['job_title'] as String? ?? ''),
                    PopupMenuButton<String>(
                      tooltip: 'Change status',
                      onSelected: (s) => _setStatus(a, s),
                      itemBuilder: (_) => [
                        for (final e in _statuses.entries.where((e) => e.key != 'submitted' && e.key != 'reviewed'))
                          PopupMenuItem(value: e.key, child: Text(e.value.$1)),
                      ],
                      child: Pill(_statuses[a['status']]?.$1 ?? 'Submitted',
                          tone: _statuses[a['status']]?.$2 ?? Tone.plain, icon: Icons.expand_more),
                    ),
                    Text(shortDate(a['applied_at'] as String?), style: context.ui.meta),
                    a['has_resume'] == true
                        ? UiButton.ghost('Resume', dense: true, onPressed: () => _openResume(a))
                        : Text('No resume', style: context.ui.meta),
                  ],
                  onTap: () => _details(a),
                ),
            ],
          ),
      ]),
    );
  }

  Widget _rescheduleBanner(Map<String, dynamic> a) {
    final r = a['reschedule_request'] as Map<String, dynamic>;
    final proposed = r['proposed_time'] as String?;
    return Panel(
      borderColor: context.ui.accent,
      child: Row(children: [
        Icon(Icons.event_repeat, color: context.ui.warn),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['applicant_name']} asked to change the interview time',
                style: context.ui.body(weight: FontWeight.w700)),
            Text([
              if ((r['note'] as String?)?.isNotEmpty ?? false) '"${r['note']}"',
              if (proposed != null) 'Suggested ${shortDate(proposed)}',
            ].join(' · '), style: context.ui.meta),
          ]),
        ),
        UiButton.ghost('Mark as handled', dense: true, onPressed: () async {
          await ApiService.resolveReschedule(a['id'] as int);
          _load();
        }),
      ]),
    );
  }

  /// One applicant's score, component by component, and their screening.
  Future<void> _details(Map<String, dynamic> a) async {
    final breakdown = (a['score_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    const parts = [('skills', 'Skills'), ('experience', 'Experience'), ('riasec', 'Interest fit'), ('text', 'Description')];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: context.ui.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.radius)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                UiAvatar(a['applicant_name'] as String? ?? '', size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['applicant_name'] as String? ?? '', style: context.ui.display(Ui.step2)),
                    Text(a['job_title'] as String? ?? '', style: context.ui.meta),
                  ]),
                ),
                MatchText(a['score'] as num?),
              ]),
              const SizedBox(height: 18),
              const Eyebrow('How the score was reached'),
              const SizedBox(height: 10),
              for (final (key, label) in parts) ...[
                Builder(builder: (_) {
                  final c = breakdown[key] as Map?;
                  final weight = (c?['weight'] as num?)?.toDouble() ?? 0;
                  final score = (c?['score'] as num?)?.toDouble();
                  return Tooltip(
                    message: c?['detail'] as String? ?? '',
                    child: score == null || weight == 0
                        ? ScoreLine(label, 0, '—')
                        : ScoreLine(label, score / 100, '${(score * weight / 100).round()} pts',
                            hint: '/ ${weight.round()}'),
                  );
                }),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const Eyebrow('Screening test'),
              const SizedBox(height: 6),
              Text(
                a['assessment_submitted'] == true
                    ? 'Submitted${a['assessment_score'] == null ? '' : ' · scored ${(a['assessment_score'] as num).round()}'}'
                    : a['assessment_pending'] == true
                        ? 'Sent, not answered yet'
                        : 'No screening test on this listing',
                style: context.ui.body(color: context.ui.muted),
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (a['has_resume'] == true)
                  UiButton('Open resume', onPressed: () {
                    Navigator.pop(dialogContext);
                    _openResume(a);
                  }),
                if (a['assessment_submitted'] == true)
                  UiButton.ghost('Screening answers', onPressed: () {
                    Navigator.pop(dialogContext);
                    _answers(a);
                  }),
                UiButton.ghost('Close', onPressed: () => Navigator.pop(dialogContext)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _answers(Map<String, dynamic> a) async {
    try {
      final data = await ApiService.getApplicationAssessmentAnswers(a['id'] as int);
      if (!mounted) return;
      final items = ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: context.ui.surface,
          title: Text(data['title'] as String? ?? 'Screening answers', style: context.ui.display(Ui.step2)),
          content: SizedBox(
            width: 520,
            child: ListView(shrinkWrap: true, children: [
              for (final it in items) ...[
                Text(it['question'] as String? ?? '', style: context.ui.body(weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${it['answer'] ?? '—'}', style: context.ui.body(color: context.ui.muted)),
                const SizedBox(height: 14),
              ],
            ]),
          ),
          actions: [UiButton.ghost('Close', onPressed: () => Navigator.pop(dialogContext))],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
