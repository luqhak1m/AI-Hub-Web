import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/user/screens/advisor_chat_screen.dart';
import 'package:aidvise_platform/user/screens/assessment_screen.dart';
import 'package:aidvise_platform/user/screens/job_listings_screen.dart';

/// Assessment — draft "List + detail": matched careers on the left; the
/// selected career, why it matched and your six interest scores on the right.
class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  static const _names = {
    'r': 'Realistic', 'i': 'Investigative', 'a': 'Artistic',
    's': 'Social', 'e': 'Enterprising', 'c': 'Conventional',
  };

  Map<String, dynamic>? _result;
  bool _loading = true;
  String? _error;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiService.getLatestAssessmentResult(refresh: true);
      if (mounted) setState(() { _result = result; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your results.'; _loading = false; });
    }
  }

  Future<void> _takeAssessment({bool retake = false}) async {
    if (retake) {
      try {
        await ApiService.startAssessmentRetake();
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(AppPageRoute(builder: (_) => AssessmentScreen(retake: retake)));
    _load();
  }

  List<MapEntry<String, num>> get _scores {
    final raw = (_result?['riasec_scores'] as Map?)?.cast<String, num>() ?? {};
    return raw.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null && _result == null) return _notTaken();
    return UiState(
      loading: _loading,
      error: _error,
      onRetry: _load,
      builder: () {
        final careers = ((_result!['occupations'] as List?) ?? []).cast<Map<String, dynamic>>();
        final top = _scores.take(3).toList();
        final sessionId = _result!['session_id'] as int?;
        return UiPage(fill: true, children: [
          ContentHead(
            eyebrow: '${top.map((e) => _names[e.key]).join(', ')} · taken ${shortDate(_result!['completed_at'] as String?)}',
            title: 'Your interest profile: ${top.map((e) => e.key.toUpperCase()).join(' · ')}',
            actions: [
              UiButton.ghost('Retake', onPressed: () => _takeAssessment(retake: true)),
              if (sessionId != null)
                UiButton('Ask the advisor',
                    onPressed: () => Navigator.of(context)
                        .push(advisorChatRoute(sessionId: sessionId, openingMessage: 'Explain my results'))),
            ],
          ),
          Expanded(
            child: UiListDetail(
              rows: [
                for (var i = 0; i < careers.length; i++)
                  ListRow(
                    leading: const IconTile(Icons.explore_outlined),
                    title: careers[i]['title'] as String? ?? '',
                    sub: 'O*NET ${careers[i]['soc_code'] ?? ''}',
                    trailing: MatchText(careers[i]['match_score'] as num?),
                    selected: !isNarrow(context) && i == _selected,
                    onTap: () => isNarrow(context)
                        ? openDetailPage(context, careers[i]['title'] as String? ?? 'Career',
                            _detail(careers[i], i + 1, sessionId))
                        : setState(() => _selected = i),
                  ),
              ],
              detail: careers.isEmpty ? null : _detail(careers[_selected], _selected + 1, sessionId),
            ),
          ),
        ]);
      },
    );
  }

  Widget _notTaken() => UiPage(children: [
        const ContentHead(eyebrow: 'About 15 minutes', title: 'Career assessment'),
        Panel(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Find the careers that fit how you like to work.', style: context.ui.display(Ui.step2)),
            const SizedBox(height: 8),
            Text('Answer questions about what you enjoy. We match your answers to hundreds of '
                'careers and show the ones that suit you best.', style: context.ui.body(color: context.ui.muted)),
            const SizedBox(height: 16),
            UiButton('Take the assessment', onPressed: _takeAssessment),
          ]),
        ),
      ]);

  Widget _detail(Map<String, dynamic> career, int rank, int? sessionId) {
    final name = career['title'] as String? ?? '';
    final holland = ((career['holland_code'] as List?) ?? []).cast<Map<String, dynamic>>();
    final scores = _scores;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Eyebrow('Career match #$rank'),
      const SizedBox(height: 10),
      Row(children: [
        const IconTile(Icons.explore_outlined, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: context.ui.display(Ui.step3)),
            Text('O*NET ${career['soc_code'] ?? ''}', style: context.ui.meta),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      FactsRow([
        ('Fit', MatchText(career['match_score'] as num?)),
        ('Rank', Text('#$rank of ${((_result!['occupations'] as List?) ?? []).length}')),
        ('Shares your interests', Text('${holland.where((h) => h['matched'] == true).length} of ${holland.length}')),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final h in holland)
          Pill(h['matched'] == true ? '${h['label']} ✓' : h['label'] as String? ?? '',
              tone: h['matched'] == true ? Tone.brand : Tone.plain),
      ]),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(career['description'] as String? ?? '', style: context.ui.body(color: context.ui.muted)),
      ),
      const SizedBox(height: 20),
      const Eyebrow('Your six interest scores'),
      const SizedBox(height: 10),
      for (var i = 0; i < scores.length; i++) ...[
        ScoreLine(_names[scores[i].key] ?? scores[i].key, scores[i].value / 100, '${scores[i].value.round()}%',
            amber: i < 3, bold: i < 3),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (sessionId != null) ...[
          UiButton('Ask the advisor about this career',
              onPressed: () => Navigator.of(context).push(advisorChatRoute(
                  sessionId: sessionId, openingMessage: 'Tell me more about $name and why it suits me'))),
          UiButton.ghost('View matched jobs',
              onPressed: () => Navigator.of(context)
                  .push(AppPageRoute(builder: (_) => JobListingsScreen(sessionId: sessionId)))),
        ],
      ]),
    ]);
  }
}
