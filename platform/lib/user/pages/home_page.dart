import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/user/pages/sections.dart';
import 'package:aidvise_platform/user/screens/interview_prep_screen.dart';
import 'package:aidvise_platform/user/screens/screening_screen.dart';

/// Job seeker home — draft "Sidebar dashboard": greeting, the one reminder
/// that needs attention, four tool tiles, and recommended jobs.
class HomePage extends StatefulWidget {
  final OpenSection open;
  const HomePage({super.key, required this.open});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _me;
  String? _profileName;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _reminder;
  List<Map<String, dynamic>> _jobs = [];
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
      final results = await Future.wait([
        ApiService.getHomeSummary(refresh: true),
        ApiService.getMe(refresh: true),
        ApiService.getLatestAssessmentResult().catchError((_) => null),
        ApiService.getMyApplications(refresh: true).catchError((_) => <Map<String, dynamic>>[]),
        ApiService.getProfile().catchError((_) => <String, dynamic>{}),
      ]);
      final result = results[2] as Map<String, dynamic>?;
      final apps = (results[3] as List).cast<Map<String, dynamic>>();
      final sessionId = result?['session_id'] as int?;
      // Best fit first when there is an assessment; otherwise the newest.
      final jobs = sessionId != null
          ? await ApiService.getJobRecommendations(sessionId).catchError((_) => <Map<String, dynamic>>[])
          : ((await ApiService.browseJobs(page: 1, pageSize: 3))['jobs'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _me = results[1] as Map<String, dynamic>;
        _result = result;
        _profileName = ((results[4] as Map)['name'] as String?)?.trim();
        _reminder = apps.where((a) => a['assessment_pending'] == true).firstOrNull ??
            apps.where((a) => a['prep_available'] == true).firstOrNull;
        _jobs = jobs.take(3).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your home page.'; _loading = false; });
    }
  }

  /// The name people know them by: profile name, account name, then username.
  String get _name {
    final user = _summary?['user'] as Map<String, dynamic>? ?? {};
    final full = (user['full_name'] as String?)?.trim();
    if (_profileName?.isNotEmpty ?? false) return _profileName!;
    return (full?.isNotEmpty ?? false) ? full! : (user['username'] as String? ?? '');
  }

  String get _firstName => _name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    return UiState(
      loading: _loading,
      error: _error,
      onRetry: _load,
      builder: () => UiPage(children: [
        _greeting(),
        if (_reminder != null) _reminderBanner(_reminder!),
        _tools(),
        if (_jobs.isNotEmpty) ...[
          SectionTitle('Recommended for you',
              link: 'See all ${_summary?['jobs']?['total'] ?? ''}', onLink: () => widget.open(UserSection.jobs)),
          _jobGrid(),
        ],
      ]),
    );
  }

  Widget _greeting() => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(longToday()),
            Text('${greeting()}, $_firstName', style: context.ui.display(Ui.step3)),
          ]),
        ),
        Clickable(onTap: () => widget.open(UserSection.profile), child: UiAvatar(_name)),
      ]);

  // `.a-remind`
  Widget _reminderBanner(Map<String, dynamic> app) {
    final screening = app['assessment_pending'] == true;
    final when = DateTime.tryParse(app['interview_at'] as String? ?? '')?.toLocal();
    final title = screening
        ? 'Screening test to complete'
        : when == null
            ? 'Interview · time to be confirmed'
            : 'Interview · ${shortDate(app['interview_at'] as String?)} · '
                '${TimeOfDay.fromDateTime(when).format(context)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Ui.radius),
        gradient: context.ui.banner,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: context.ui.body(weight: FontWeight.w700, color: Colors.white)),
            Text('${app['job_title']} at ${app['company']}',
                style: context.ui.body(color: Colors.white.withValues(alpha: 0.85))),
          ]),
          UiButton.accent(screening ? 'Start screening test' : 'View prep pack', onPressed: () async {
            await Navigator.of(context).push(AppPageRoute(
              builder: (_) => screening
                  ? ScreeningScreen(applicationId: app['id'] as int)
                  : InterviewPrepScreen(applicationId: app['id'] as int),
            ));
            _load();
          }),
        ],
      ),
    );
  }

  // `.a-tools`
  Widget _tools() {
    final resumes = (_me?['limits'] as Map?)?['resume_generations_per_month'] as Map?;
    final scores = (_result?['riasec_scores'] as Map?)?.cast<String, num>();
    final code = scores == null
        ? null
        : (scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => e.key.toUpperCase())
            .join('');
    final apps = (_summary?['applications'] as Map?)?['total'] as int? ?? 0;
    final tiles = [
      (Icons.explore_outlined, 'Assessment', code == null ? 'Not taken yet' : 'Done · $code',
          code == null ? Tone.plain : Tone.good, UserSection.assessment),
      (Icons.description_outlined, 'Resumes',
          resumes == null ? 'Generate one' : '${resumes['used']} of ${resumes['limit'] ?? '∞'} this month',
          Tone.plain, UserSection.resumes),
      (Icons.work_outline, 'Find jobs', '${_summary?['jobs']?['total'] ?? 0} jobs', Tone.brand, UserSection.jobs),
      (Icons.fact_check_outlined, 'Applications', '$apps active', Tone.warn, UserSection.applications),
    ];
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth < 520 ? 1 : box.maxWidth < 760 ? 2 : 4;
      final width = (box.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (icon, title, status, tone, section) in tiles)
          SizedBox(
            width: width,
            child: Panel(
              onTap: () => widget.open(section),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconTile(icon),
                const SizedBox(height: 14),
                Text(title.toUpperCase(),
                    style: context.ui.body(weight: FontWeight.w800, color: context.ui.brand).copyWith(letterSpacing: 0.06 * Ui.step0)),
                const SizedBox(height: 14),
                Pill(status, tone: tone),
              ]),
            ),
          ),
      ]);
    });
  }

  // `.a-jobs`
  Widget _jobGrid() => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth < 760 ? 1 : 3;
        final width = (box.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final job in _jobs)
            SizedBox(
              width: width,
              child: Panel(
                onTap: () => widget.open(UserSection.jobs, arg: job['id']),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    LogoTile(job['company'] as String? ?? ''),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(job['title'] as String? ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: context.ui.body(size: Ui.step1, weight: FontWeight.w700)),
                        Text('${job['company'] ?? ''} · ${job['location'] ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: context.ui.meta),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(job['salary'] as String? ?? 'Salary not stated',
                      style: context.ui.body().copyWith(fontFeatures: Ui.tabular)),
                  const SizedBox(height: 12),
                  Row(children: [
                    MatchText(job['match_score'] as num?, suffix: ' match'),
                    const Spacer(),
                    Text(job['posted'] as String? ?? '', style: context.ui.meta),
                  ]),
                ]),
              ),
            ),
        ]);
      });
}
