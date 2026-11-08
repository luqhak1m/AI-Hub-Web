import 'dart:async';

import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/user/utils/job_apply.dart';

/// Jobs — draft "List + detail": jobs with your match on the left, the
/// selected job and why you match it on the right.
class JobsPage extends StatefulWidget {
  /// Job to open first (e.g. from a home recommendation).
  final int? initialJobId;
  const JobsPage({super.key, this.initialJobId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  Timer? _debounce;
  final List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filters = [];
  int? _occupationId;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialJobId;
    ApiService.getJobBrowseFilters().then((f) {
      if (mounted) setState(() => _filters = f);
    }).catchError((_) {});
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _page = 1;
      }
    });
    try {
      final result = await ApiService.browseJobs(
        search: _search.text.trim(),
        occupationId: _occupationId,
        page: more ? _page + 1 : 1,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (!more) _jobs.clear();
        if (more) _page += 1;
        _jobs.addAll((result['jobs'] as List).cast<Map<String, dynamic>>());
        _total = result['total'] as int? ?? _jobs.length;
        _hasMore = result['has_more'] as bool? ?? false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load jobs.');
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  Map<String, dynamic>? get _selected {
    if (_jobs.isEmpty) return null;
    return _jobs.where((j) => j['id'] == _selectedId).firstOrNull ?? _jobs.first;
  }

  void _open(Map<String, dynamic> job) {
    if (isNarrow(context)) {
      openDetailPage(context, job['title'] as String? ?? 'Job', JobDetail(job: job, onApplied: _load));
    } else {
      setState(() => _selectedId = job['id'] as int?);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiPage(fill: true, children: [
      ContentHead(
        eyebrow: _loading ? null : '$_total live jobs · your match on each',
        title: 'Jobs for you',
        actions: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _search,
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
              style: context.ui.body(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search jobs, companies or skills',
                hintStyle: context.ui.body(color: context.ui.muted),
                prefixIcon: Icon(Icons.search, size: 18, color: context.ui.muted),
                filled: true,
                fillColor: context.ui.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.line)),
              ),
            ),
          ),
        ],
      ),
      Expanded(
        child: UiState(
          loading: _loading,
          error: _error,
          onRetry: _load,
          empty: _jobs.isEmpty,
          emptyText: 'No jobs match your search.',
          builder: () => UiListDetail(
            // One line of filters, like the draft; scrolls sideways when long.
            header: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
              UiChip('All', selected: _occupationId == null, onTap: () {
                _occupationId = null;
                _load();
              }),
              for (final f in _filters.take(6))
                UiChip('${f['title']} (${f['count']})', selected: _occupationId == f['id'], onTap: () {
                  _occupationId = f['id'] as int?;
                  _load();
                }),
            ].expand((chip) => [chip, const SizedBox(width: 6)]).toList()),
            ),
            rows: [
              for (final job in _jobs)
                ListRow(
                  leading: LogoTile(job['company'] as String? ?? ''),
                  title: job['title'] as String? ?? '',
                  sub: '${job['company'] ?? ''} · ${job['location'] ?? ''}',
                  trailing: MatchText(job['match_score'] as num?),
                  selected: !isNarrow(context) && job['id'] == _selected?['id'],
                  onTap: () => _open(job),
                ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: UiButton.ghost('Load more', busy: _loadingMore, onPressed: () => _load(more: true)),
                  ),
                ),
            ],
            detail: _selected == null
                ? null
                : JobDetail(key: ValueKey(_selected!['id']), job: _selected!, onApplied: _load),
          ),
        ),
      ),
    ]);
  }
}

/// One job, as the right side of the jobs page (or its own page on narrow
/// windows): facts, the match breakdown, skills and description, and the two
/// ways to apply.
class JobDetail extends StatefulWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onApplied;
  const JobDetail({super.key, required this.job, this.onApplied});

  @override
  State<JobDetail> createState() => _JobDetailState();
}

class _JobDetailState extends State<JobDetail> {
  Map<String, dynamic>? _match;

  // Display order and labels for the scoring components.
  static const _components = [
    ('skills', 'Skills'),
    ('experience', 'Experience'),
    ('riasec', 'Interest fit'),
    ('text', 'Description'),
  ];

  @override
  void initState() {
    super.initState();
    final id = widget.job['id'] as int?;
    if (id != null) {
      ApiService.getJobMatch(id).then((m) {
        if (mounted) setState(() => _match = m);
      }).catchError((_) {});
    }
  }

  Future<void> _apply(Future<void> Function(BuildContext, Map<String, dynamic>) flow) async {
    await flow(context, widget.job);
    widget.onApplied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final applied = job['applied'] == true;
    final skills = _match?['skills'] as Map<String, dynamic>?;
    final matched = ((skills?['matched'] as List?) ?? []).cast<String>();
    final missing = ((skills?['missing'] as List?) ?? []).cast<String>();
    final required = ((job['required_skills'] as List?) ?? []).cast<String>();
    final overall = _match?['overall'] as num? ?? job['match_score'] as num?;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        LogoTile(job['company'] as String? ?? '', size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(job['title'] as String? ?? '', style: context.ui.display(Ui.step3)),
            Text(
              [job['company'], job['location'], if (job['posted'] != null) 'Posted ${job['posted']}']
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: context.ui.meta,
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      FactsRow([
        ('Salary', Text(job['salary'] as String? ?? 'Not stated')),
        ('Type', Text(job['type'] as String? ?? '—')),
        ('Your match', MatchText(overall)),
      ]),
      const SizedBox(height: 20),
      const Eyebrow('Why you match'),
      const SizedBox(height: 10),
      if (_match == null)
        Text('Working out your match…', style: context.ui.meta)
      else
        for (final (key, label) in _components) ...[
          _componentLine(label, _match![key] as Map<String, dynamic>?),
          const SizedBox(height: 10),
        ],
      if (matched.isNotEmpty || missing.isNotEmpty || required.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Eyebrow('Skills they want'),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (matched.isNotEmpty || missing.isNotEmpty) ...[
            for (final s in matched) Pill('$s ✓', tone: Tone.good),
            for (final s in missing) Pill(s),
          ] else
            for (final s in required) Pill(s),
        ]),
      ],
      const SizedBox(height: 20),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(job['description'] as String? ?? '', style: context.ui.body(color: context.ui.muted)),
      ),
      const SizedBox(height: 20),
      if (applied)
        const Pill('Applied', tone: Tone.good, icon: Icons.check)
      else
        Wrap(spacing: 10, runSpacing: 10, children: [
          UiButton('Apply with tailored resume', onPressed: () => _apply(applyWithTailoredResume)),
          UiButton.ghost('Upload my own PDF', onPressed: () => _apply(applyWithUpload)),
        ]),
    ]);
  }

  /// "Skills / 40 ─────── 36 pts": the component's weight and the points it
  /// contributed. A component the listing can't be scored on says why.
  Widget _componentLine(String label, Map<String, dynamic>? c) {
    final weight = (c?['weight'] as num?)?.toDouble() ?? 0;
    final score = (c?['score'] as num?)?.toDouble();
    if (score == null || weight == 0) {
      return ScoreLine(label, 0, '—', hint: c?['detail'] == null ? null : '');
    }
    final points = score * weight / 100;
    return Tooltip(
      message: c?['detail'] as String? ?? '',
      child: ScoreLine(label, score / 100, '${points.round()} pts', hint: '/ ${weight.round()}'),
    );
  }
}
