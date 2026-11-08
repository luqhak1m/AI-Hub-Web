import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/widgets/job_card.dart';
import 'package:aidvise_platform/user/widgets/job_details_sheet.dart';
import 'package:aidvise_platform/user/utils/job_apply.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

class JobListingsScreen extends StatefulWidget {
  final int sessionId;
  const JobListingsScreen({super.key, required this.sessionId});

  @override
  State<JobListingsScreen> createState() => _JobListingsScreenState();
}

class _JobListingsScreenState extends State<JobListingsScreen> {
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
      final jobs = await ApiService.getJobRecommendations(widget.sessionId);
      setState(() { _jobs = jobs; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load jobs. Check your connection.'; _loading = false; });
    }
  }

  /// Groups jobs by occupation. `_jobs` arrives ordered by fit, so map
  /// insertion order is already rank order and needs no re-sorting.
  List<MapEntry<String, List<Map<String, dynamic>>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final job in _jobs) {
      final occupation = job['occupation'] as String? ?? 'Other';
      map.putIfAbsent(occupation, () => []).add(job);
    }
    return map.entries.toList();
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
        title: const Text('Matched Jobs', style: TextStyle(color: AppTheme.primary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? _buildError()
              : _jobs.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Ui.muted, fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white, elevation: 0),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Text('No matching jobs found.', style: TextStyle(color: Ui.muted)),
      );

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'Jobs matched to your results',
          style: TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Curated from your top career paths, ranked by fit.',
          style: TextStyle(color: Ui.muted, fontSize: 14),
        ),
        const SizedBox(height: 20),
        for (final entry in _grouped) ..._buildOccupationSection(entry.key, entry.value),
      ],
    );
  }

  List<Widget> _buildOccupationSection(String occupation, List<Map<String, dynamic>> jobs) {
    final rank = jobs.isNotEmpty ? (jobs.first['rank'] as int? ?? 0) : 0;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('#$rank',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(occupation,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
          ],
        ),
      ),
      ...jobs.map((job) => JobCard(
            job: job,
            onTap: () => showJobDetailsSheet(
                  context,
                  job,
                  onApply: () async {
                    await applyToJob(context, job);
                    if (mounted) _load(); // pick up the applied flag
                  },
                ),
            onApply: () async {
              await applyToJob(context, job);
              if (mounted) _load(); // pick up the applied flag
            },
          )),
      const SizedBox(height: 16),
    ];
  }

}
