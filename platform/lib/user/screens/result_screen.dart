import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/screens/assessment_screen.dart';
import 'package:aidvise_platform/user/screens/job_listings_screen.dart';
import 'package:aidvise_platform/user/screens/advisor_chat_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/user/widgets/occupation_sheet.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final int? _sessionId;
  late final List<Map<String, dynamic>> _occupations;
  late final String? _completedOn;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.result['session_id'] as int?;
    _occupations = (widget.result['occupations'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    _completedOn = _formatCompletedAt(widget.result['completed_at'] as String?);
  }

  static String? _formatCompletedAt(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Taken ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Slides the full-screen advisor in over the results.
  void _openAdvisor({String? opening}) {
    if (_sessionId == null) return;
    Navigator.of(context).push(
      advisorChatRoute(sessionId: _sessionId!, openingMessage: opening),
    );
  }

  Future<void> _retakeAssessment() async {
    try {
      // Clear the server-side latest flag first, so the retake survives an
      // app restart (no flag = the assessment shows questions).
      await ApiService.startAssessmentRetake();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      // Non-fatal: the retake flag also skips the check locally.
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppPageRoute(builder: (_) => const AssessmentScreen(retake: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Your Results',
            style: TextStyle(
                color: AppTheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        actions: [
          if (_sessionId != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Career Advisor',
                onPressed: () => _openAdvisor(),
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.smart_toy,
                      color: Colors.white, size: 21),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_completedOn != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  _completedOn!,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12),
                ),
              ),
            ],
            ..._occupations
                .asMap()
                .entries
                .map((e) => _buildOccupationCard(e.value, e.key + 1)),
            const SizedBox(height: 6),
            if (_sessionId != null) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.work_outline, size: 18),
                  label: const Text('View Matched Jobs',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => JobListingsScreen(sessionId: _sessionId!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Explain My Results',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openAdvisor(opening: 'Explain my results'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _retakeAssessment,
                child: const Text(
                  'Retake Assessment',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openOccupationSheet(Map<String, dynamic> occupation, int rank) {
    final name = occupation['title'] as String? ?? '';
    showOccupationSheet(
      context,
      occupation,
      rank: rank,
      onAskAdvisor: _sessionId == null
          ? null
          : () => _openAdvisor(
              opening: 'Tell me more about $name and why it suits me'),
    );
  }

  Widget _buildOccupationCard(Map<String, dynamic> occupation, int rank) {
    final name = occupation['title'] as String? ?? '';
    final score = (occupation['match_score'] as num?)?.round();
    final holland = (occupation['holland_code'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    // Strongest first: matched dimensions lead, and within each group the
    // higher-scoring dimension comes first.
    double strength(Map<String, dynamic> h) =>
        (h['score'] as num?)?.toDouble() ?? 0;
    final sortedHolland = [...holland]..sort((a, b) {
        final matchRank = (b['matched'] == true ? 1 : 0)
            .compareTo(a['matched'] == true ? 1 : 0);
        return matchRank != 0 ? matchRank : strength(b).compareTo(strength(a));
      });

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        title: '$rank. $name',
        tags: [
          for (final entry in sortedHolland)
            CardTag(entry['label'] as String? ?? '',
                filled: entry['matched'] == true),
        ],
        // Right of the tags, not on the title row — field names run long.
        tagsMeta: score != null ? '$score%' : null,
        onTap: () => _openOccupationSheet(occupation, rank),
      ),
    );
  }
}
