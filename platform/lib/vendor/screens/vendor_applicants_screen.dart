import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/widgets/application_dashboard.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/screens/pdf_viewer_screen.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/shared/widgets/detail_sheet.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Vendor applicant review: a Dashboard tab (stats and charts) and an
/// Applicants tab (filterable, sortable, scored candidate list).
class VendorApplicantsScreen extends StatefulWidget {
  const VendorApplicantsScreen({super.key});

  @override
  State<VendorApplicantsScreen> createState() => _VendorApplicantsScreenState();
}

class _VendorApplicantsScreenState extends State<VendorApplicantsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _applications = [];

  // Applicant filters: minimum score per component (0 = any) + sort order.
  final Map<String, int> _minScores = {
    'overall': 0, 'skills': 0, 'experience': 0, 'riasec': 0, 'text': 0,
  };
  static const _sortModes = ['Score', 'Status', 'Newest'];
  int _sortMode = 0;
  static const _statusLabels = {
    'submitted': 'Submitted',
    'reviewed': 'Reviewed',
    'shortlisted': 'Shortlisted',
    'interview': 'Interview',
    'hired': 'Hired',
    'rejected': 'Not selected',
  };

  // Workflow order: in-review first, fresh submissions next, then the
  // later pipeline stages, decided last.
  static const _statusOrder = {
    'reviewed': 0, 'submitted': 1, 'interview': 2, 'shortlisted': 3,
    'hired': 4, 'rejected': 5,
  };

  static const _filterLabels = {
    'overall': 'Overall', 'skills': 'Skills', 'experience': 'Experience',
    'riasec': 'Fit', 'text': 'Text',
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final applications = await ApiService.getVendorApplications();
      setState(() { _applications = applications; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load applicants.'; _loading = false; });
    }
  }

  Future<void> _setApplicationStatus(int applicationId, String status) async {
    try {
      await ApiService.setApplicationStatus(applicationId, status);
      _load();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  double? _componentScore(Map<String, dynamic> application, String key) {
    if (key == 'overall') return (application['score'] as num?)?.toDouble();
    final breakdown = application['score_breakdown'] as Map<String, dynamic>?;
    return ((breakdown?[key] as Map<String, dynamic>?)?['score'] as num?)?.toDouble();
  }

  List<Map<String, dynamic>> get _filteredApplications {
    final list = _applications.where((a) {
      for (final entry in _minScores.entries) {
        if (entry.value == 0) continue;
        final score = _componentScore(a, entry.key);
        if (score == null || score < entry.value) return false;
      }
      return true;
    }).toList();

    int newest(Map<String, dynamic> x, Map<String, dynamic> y) =>
        ((y['id'] as int?) ?? 0).compareTo((x['id'] as int?) ?? 0);

    switch (_sortModes[_sortMode]) {
      case 'Score':
        list.sort((x, y) => ((y['score'] as num?) ?? -1)
            .compareTo((x['score'] as num?) ?? -1));
      case 'Status':
        list.sort((x, y) {
          final byStatus = (_statusOrder[x['status']] ?? 9)
              .compareTo(_statusOrder[y['status']] ?? 9);
          return byStatus != 0 ? byStatus : newest(x, y);
        });
      case 'Newest':
        list.sort(newest);
    }
    return list;
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
        title: const Text('Applicants', style: TextStyle(color: AppTheme.primary)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: const Color(0xFF888888),
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Dashboard'),
            Tab(text: 'Applicants (${_applications.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : _applications.isEmpty
                  ? _emptyState()
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildDashboardTab(),
                        _buildApplicantsTab(),
                      ],
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

  Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 40, color: Color(0xFFCCCCCC)),
            SizedBox(height: 12),
            Text('No applicants yet.',
                style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
            SizedBox(height: 6),
            Text('Applications to your listings will appear here.',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ApplicationDashboard(applications: _applications),
        ],
      ),
    );
  }

  Widget _buildApplicantsTab() {
    final filtered = _filteredApplications;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text('APPLICANTS (${filtered.length}/${_applications.length})',
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const Spacer(),
                GestureDetector(
                  onTap: _showScoringInfo,
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Color(0xFF888888)),
                    SizedBox(width: 4),
                    Text('How scoring works',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
                  ]),
                ),
              ],
            ),
          ),
          _buildFilterRow(),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                  child: Text('No applicants match the filters.',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 13))),
            ),
          ...filtered.map(_buildApplicationCard),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Sort cycle: Score -> Status (reviewed, submitted, shortlisted,
          // rejected) -> Newest
          GestureDetector(
            onTap: () => setState(
                () => _sortMode = (_sortMode + 1) % _sortModes.length),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFCCCCCC)),
              ),
              child: Row(children: [
                const Icon(Icons.swap_vert, size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(_sortModes[_sortMode],
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          ..._filterLabels.entries.map((entry) {
            final key = entry.key;
            final active = _minScores[key]! > 0;
            return PopupMenuButton<int>(
              initialValue: _minScores[key],
              color: Colors.white,
              onSelected: (v) => setState(() => _minScores[key] = v),
              itemBuilder: (_) => [0, 40, 60, 80]
                  .map((threshold) => PopupMenuItem(
                        value: threshold,
                        height: 38,
                        child: Text(threshold == 0 ? 'Any' : '≥ $threshold',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                margin: const EdgeInsets.only(right: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                      color: active ? AppTheme.primary : const Color(0xFFCCCCCC)),
                ),
                child: Text(
                  active ? '${entry.value} ≥ ${_minScores[key]}' : entry.value,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF666666),
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showScoringInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('How applicant scoring works',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const SingleChildScrollView(
          child: Text(
            'Every application gets a deterministic 0–100 score — no AI '
            'guesswork, the same inputs always give the same score.\n\n'
            'SKILLS (40%)\nMatched required skills ÷ skills you listed on the '
            'job. Synonyms are normalised (e.g. "JS" = "JavaScript").\n\n'
            'EXPERIENCE (25%)\n60% tenure: total years of work, full marks at '
            '5 years. 40% title relevance: word overlap between their past '
            'job titles and yours.\n\n'
            'INTEREST FIT (20%)\nThe candidate\'s career assessment profile '
            'compared to this role\'s occupation profile from O*NET (the same '
            'method as the assessment results). Skipped, with its weight '
            'shared out, when a listing has no occupation set.\n\n'
            'TEXT RELEVANCE (15%)\nBM25 keyword relevance of their resume '
            'against your job description. Rare, specific terms count more '
            'than common words.\n\n'
            'If a component can\'t be computed (no required skills set, or '
            'the candidate hasn\'t taken the assessment), its weight is '
            'redistributed across the others.',
            style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF444444)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  /// Vendor view of a candidate's submitted screening answers.
  Future<void> _showAssessmentAnswers(int applicationId, String applicant) async {
    Map<String, dynamic> view;
    try {
      view = await ApiService.getApplicationAssessmentAnswers(applicationId);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    final items = (view['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final score = view['score'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('${view['title'] ?? 'Assessment'} — $applicant',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              score != null
                  ? 'Auto-score on objective questions: ${(score as num).round()}/100'
                  : 'No auto-scored questions in this assessment.',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              final type = item['type'] as String? ?? '';
              final answer = item['answer'];
              final stars = (answer is num) ? answer.round().clamp(0, 5) : 0;
              final display = switch (type) {
                'choice' => item['answer_label'] as String? ?? '$answer',
                'rating' => '★' * stars + '☆' * (5 - stars),
                'slider' => answer is num ? '${answer.round()} / 100' : '—',
                _ => '$answer',
              };
              final correct = item['correct'] as bool?;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ${item['question']}',
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 12.5, height: 1.4)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (correct != null) ...[
                          Icon(correct ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: correct ? AppTheme.primary : const Color(0xFFEF233C)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(display,
                              style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 13.5,
                                  fontWeight: FontWeight.w600, height: 1.4)),
                        ),
                      ],
                    ),
                    if (correct == false)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('Correct: ${item['correct_label']}',
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 11.5)),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final id = application['id'] as int;
    final status = application['status'] as String? ?? 'submitted';
    final hasResume = application['has_resume'] == true;
    final score = (application['score'] as num?)?.toDouble();
    final reschedule = application['reschedule_request'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          AppCard(
            compact: true,
            image: _scoreBadge(score),
            title: application['applicant_name'] as String? ?? '',
            titleMeta: _statusLabels[status],
            description: application['job_title'] as String? ?? '',
            status: hasResume ? null : 'No resume attached',
            statusIcon: hasResume ? null : Icons.description_outlined,
            // The score breakdown and screening answers live in the detail
            // sheet, the same way every other card in the app expands.
            onTap: () => _showApplicantDetails(application),
            actions: [
              if (hasResume)
                _smallAction(
                  icon: Icons.description_outlined,
                  label: 'Resume',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      AppPageRoute(
                        builder: (_) => PdfViewerScreen(
                          title: 'Applicant Resume',
                          pdfPath: ApiService.applicantResumePath(id),
                          downloadName: 'applicant_resume_$id',
                        ),
                      ),
                    );
                    _load(); // opening the resume auto-marks it reviewed
                  },
                ),
              _statusDropdown(id, status),
            ],
          ),
          if (reschedule != null) ...[
            const SizedBox(height: 8),
            _buildRescheduleBanner(id, reschedule),
          ],
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
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 14),
        label: Text(label,
            style:
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppTheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
      ),
    );
  }

  /// Everything about one applicant that does not belong on the summary card:
  /// how their match score was reached, and their screening answers.
  void _showApplicantDetails(Map<String, dynamic> application) {
    final id = application['id'] as int;
    final applicant = application['applicant_name'] as String? ?? '';
    final score = (application['score'] as num?)?.toDouble();
    final breakdown = application['score_breakdown'] as Map<String, dynamic>?;
    final submitted = application['assessment_submitted'] == true;
    final assessmentScore = application['assessment_score'] as num?;

    showDetailSheet(
      context,
      title: applicant,
      meta: score == null ? null : '${score.round()}%',
      subtitle: application['job_title'] as String?,
      initialSize: 0.6,
      sections: [
        if (breakdown != null)
          DetailSection(
            title: 'How this score was reached',
            icon: Icons.insights,
            child: _buildScoreBreakdown(breakdown),
          ),
        DetailSection(
          title: 'Screening assessment',
          icon: Icons.quiz_outlined,
          child: Text(
            submitted
                ? assessmentScore != null
                    ? 'Submitted — scored ${assessmentScore.round()}. '
                        'Open the answers below.'
                    : 'Submitted. Open the answers below.'
                : application['assessment_pending'] == true
                    ? 'Sent to the candidate, not answered yet.'
                    : 'No screening assessment on this listing.',
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 14, height: 1.55),
          ),
        ),
      ],
      actionLabel: submitted ? 'View screening answers' : null,
      actionIcon: Icons.fact_check_outlined,
      onAction:
          submitted ? () => _showAssessmentAnswers(id, applicant) : null,
    );
  }

  Widget _buildRescheduleBanner(int applicationId, Map<String, dynamic> request) {
    final proposed =
        DateTime.tryParse(request['proposed_time'] as String? ?? '')?.toLocal();
    String? proposedLabel;
    if (proposed != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = proposed.hour % 12 == 0 ? 12 : proposed.hour % 12;
      final minute = proposed.minute.toString().padLeft(2, '0');
      final period = proposed.hour >= 12 ? 'PM' : 'AM';
      proposedLabel = '${proposed.day} ${months[proposed.month - 1]} '
          '${proposed.year}, $hour:$minute $period';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_send, size: 15, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('TIME CHANGE REQUESTED',
                  style: TextStyle(
                      color: AppTheme.primary, fontSize: 10.5,
                      fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            ],
          ),
          const SizedBox(height: 6),
          Text('"${request['note']}"',
              style: const TextStyle(
                  color: Color(0xFF444444), fontSize: 12.5, height: 1.4)),
          if (proposedLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Suggested: $proposedLabel',
                  style: const TextStyle(
                      color: AppTheme.primary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                try {
                  await ApiService.resolveReschedule(applicationId);
                  _load();
                } on ApiException catch (e) {
                  if (mounted && handleSessionExpiry(context, e)) return;
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Mark as handled',
                  style: TextStyle(
                      color: AppTheme.primary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(double? score) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: score == null ? Colors.white : AppTheme.primary,
        shape: BoxShape.circle,
        border: score == null ? Border.all(color: const Color(0xFFCCCCCC)) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        score == null ? '—' : '${score.round()}',
        style: TextStyle(
          color: score == null ? const Color(0xFF999999) : Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Per-component score rows: label + weight, bar, score, and the
  /// calculation detail string produced by the backend.
  Widget _buildScoreBreakdown(Map<String, dynamic> breakdown) {
    const components = [
      ('skills', 'Skills'),
      ('experience', 'Experience'),
      ('riasec', 'Interest Fit'),
      ('text', 'Text Relevance'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: components.map((component) {
          final (key, label) = component;
          final data = breakdown[key] as Map<String, dynamic>? ?? {};
          final score = (data['score'] as num?)?.toDouble();
          final weight = (data['weight'] as num?)?.toDouble() ?? 0;
          final detail = data['detail'] as String? ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    if (score != null)
                      Text('${weight.round()}%',
                          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 10.5)),
                    const Spacer(),
                    Text(score == null ? 'N/A' : '${score.round()}',
                        style: TextStyle(
                            color: score == null ? const Color(0xFFAAAAAA) : AppTheme.primary,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (score ?? 0) / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 3),
                Text(detail,
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusDropdown(int applicationId, String current) {
    const options = {
      'submitted': 'Submitted',
      'reviewed': 'Reviewed',
      'shortlisted': 'Shortlisted',
      'interview': 'Interview',
      'hired': 'Hired',
      'rejected': 'Rejected',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          dropdownColor: Colors.white,
          iconSize: 16,
          iconEnabledColor: AppTheme.primary,
          // "submitted" and "reviewed" are states, not choices: reviewed is
          // set automatically when the vendor opens the applicant's resume.
          items: options.entries
              .where((e) =>
                  e.key == current ||
                  !const {'submitted', 'reviewed'}.contains(e.key))
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(
                            color: AppTheme.primary, fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null &&
                value != current &&
                value != 'submitted' &&
                value != 'reviewed') {
              _setApplicationStatus(applicationId, value);
            }
          },
        ),
      ),
    );
  }
}
