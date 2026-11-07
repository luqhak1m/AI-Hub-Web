import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';

/// The user's private career dashboard. Every figure comes from their own
/// record, so nothing moves because the job market did. Not shared with
/// employers and never compared against other users.
class CareerProgressScreen extends StatefulWidget {
  /// Opens the profile editor so an empty dashboard has somewhere to go.
  final VoidCallback? onAddExperience;
  const CareerProgressScreen({super.key, this.onAddExperience});

  @override
  State<CareerProgressScreen> createState() => _CareerProgressScreenState();
}

class _CareerProgressScreenState extends State<CareerProgressScreen> {
  Map<String, dynamic>? _progress;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh) setState(() => _loading = true);
    try {
      final progress = await ApiService.getCareerProgress(refresh: refresh);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your progress.';
        _loading = false;
      });
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
        title: const Text('Career Progress',
            style: TextStyle(
                color: AppTheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: _progress!['started'] == true
                        ? _buildDashboard()
                        : _buildEmptyState(),
                  ),
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF888888))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  // ── Populated ──────────────────────────────────────────────────────────────

  List<Widget> _buildDashboard() {
    final stats = _progress!['stats'] as Map<String, dynamic>? ?? {};
    return [
      _statTiles(stats),
      const SizedBox(height: 14),
      _alignmentCard(),
      const SizedBox(height: 14),
      _timelineCard(),
      const SizedBox(height: 14),
      _milestonesCard(),
      const SizedBox(height: 14),
      _privacyNote(),
    ];
  }

  Widget _statTiles(Map<String, dynamic> stats) {
    final years = (stats['years_experience'] as num?)?.toDouble() ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      children: [
        _stat(years == years.roundToDouble()
            ? years.toStringAsFixed(0)
            : years.toStringAsFixed(1), 'Years experience'),
        _stat('${stats['roles'] ?? 0}', 'Roles held'),
        _stat('${stats['skills'] ?? 0}', 'Skills'),
        _stat('${stats['certifications'] ?? 0}', 'Certifications'),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardHairline, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              fontFamilyFallback: ['Courier New', 'Courier'],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _alignmentCard() {
    final alignment = _progress!['alignment'] as Map<String, dynamic>? ?? {};
    final state = alignment['state'] as String? ?? 'unknown';
    final workedIn = alignment['worked_in'] as Map<String, dynamic>?;
    final suitedTo = alignment['suited_to'] as Map<String, dynamic>?;

    final explanation = switch (state) {
      'aligned' =>
        'Your recent work is already in the field your answers point to. '
            'That is worth knowing — it means the experience you are building counts '
            'towards where you want to be.',
      'different' =>
        'Your recent roles sit in a different field to the one your answers point to. '
            'That gap is normal for someone considering a change, and it is what the '
            'matched jobs and tailored resumes are there to close.',
      _ => suitedTo == null
          ? 'Take the assessment and this will show how your experience compares with '
              'the fields that suit you.'
          : 'Your job titles are not close enough to any one field for us to say '
              'where your experience sits. Adding more detail to your roles will help.',
    };

    return _panel(
      title: 'Alignment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workedIn != null)
            _alignmentRow("You've worked in", workedIn['name'] as String? ?? '',
                'Based on your recent job titles'),
          if (workedIn != null && suitedTo != null)
            const Divider(height: 18, color: AppTheme.cardHairline),
          if (suitedTo != null)
            _alignmentRow("You're suited to", suitedTo['name'] as String? ?? '',
                'Your top assessment match'),
          if (workedIn != null || suitedTo != null)
            const SizedBox(height: 12),
          Text(
            explanation,
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 13.5, height: 1.5),
          ),
          if (workedIn != null) ...[
            const SizedBox(height: 10),
            Text(
              alignment['basis'] as String? ?? '',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
                fontFamilyFallback: ['Courier New', 'Courier'],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _alignmentRow(String label, String value, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                height: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.3)),
              Text(detail,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 11.5, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineCard() {
    final timeline =
        (_progress!['timeline'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (timeline.isEmpty) {
      return _panel(
        title: 'Your history',
        child: const Text(
          'Add your roles and study and they will appear here as a timeline.',
          style: TextStyle(
              color: AppTheme.primary, fontSize: 13.5, height: 1.5),
        ),
      );
    }

    return _panel(
      title: 'Your history',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < timeline.length; i++)
            _timelineEntry(timeline[i], last: i == timeline.length - 1),
        ],
      ),
    );
  }

  Widget _timelineEntry(Map<String, dynamic> entry, {required bool last}) {
    final isCurrent = entry['is_current'] == true;
    final start = entry['start'] as String? ?? '';
    final end = entry['end'] as String?;
    final when = isCurrent
        ? '$start — present'
        : (end == null || end.isEmpty ? start : '$start — $end');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? AppTheme.accent : AppTheme.cardGreyDeep,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: AppTheme.cardHairline),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    when.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      fontFamilyFallback: ['Courier New', 'Courier'],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(entry['title'] as String? ?? '',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  if ((entry['detail'] as String? ?? '').isNotEmpty)
                    Text(entry['detail'] as String? ?? '',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestonesCard() {
    final milestones =
        (_progress!['milestones'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final reached = _progress!['milestones_reached'] ?? 0;
    final total = _progress!['milestones_total'] ?? milestones.length;

    return _panel(
      title: 'Milestones',
      trailing: '$reached / $total',
      child: Column(
        children: [
          for (var i = 0; i < milestones.length; i++)
            _milestoneRow(milestones[i], first: i == 0),
        ],
      ),
    );
  }

  Widget _milestoneRow(Map<String, dynamic> milestone, {required bool first}) {
    final reached = milestone['reached'] == true;
    final progress = milestone['progress'] as Map<String, dynamic>?;
    final subtitle = reached
        ? _relativeDate(milestone['awarded_at'] as String?)
        : progress != null
            ? '${progress['current']} of ${progress['target']}'
            : milestone['hint'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(
                top: BorderSide(color: AppTheme.cardHairline, width: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: reached ? AppTheme.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: reached
                  ? null
                  : Border.all(color: AppTheme.cardHairline, width: 1.5),
            ),
            child: reached
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone['title'] as String? ?? '',
                  style: TextStyle(
                    color: reached
                        ? AppTheme.primary
                        : AppTheme.primary.withValues(alpha: 0.55),
                    fontSize: 13.5,
                    fontWeight: reached ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 11.5, height: 1.35),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────────

  List<Widget> _buildEmptyState() {
    final milestones =
        (_progress!['milestones'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return [
      _panel(
        title: 'Start here',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This page fills in as you go. Add your experience and take the '
              'assessment, and it will show your history, how your work compares '
              'with what suits you, and everything you have reached so far.',
              style: TextStyle(
                  color: AppTheme.primary, fontSize: 13.5, height: 1.55),
            ),
            if (widget.onAddExperience != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onAddExperience!();
                  },
                  child: const Text('Add your experience',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _panel(
        title: 'Milestones',
        trailing: '0 / ${milestones.length}',
        child: Column(
          children: [
            for (var i = 0; i < milestones.length && i < 4; i++)
              _milestoneRow(milestones[i], first: i == 0),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _privacyNote(),
    ];
  }

  Widget _privacyNote() {
    return const AppCard(
      icon: Icons.lock_outline,
      title: 'Private to you',
      description:
          'Nothing on this page is shared with employers or compared with other '
          'people. It is your own record.',
    );
  }

  // ── Shared shell ───────────────────────────────────────────────────────────

  Widget _panel({
    required String title,
    String? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardHairline, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Courier New', 'Courier'],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  /// "3d", "Jul", or the year for anything older.
  static String _relativeDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 24) return 'Today';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (diff.inDays < 365) return months[dt.month - 1];
    return '${dt.year}';
  }
}
