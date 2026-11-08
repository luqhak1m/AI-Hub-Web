import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Admin view of failed background generations: review the error, retry
/// after fixing the cause. Rows disappear once a retry succeeds (the job
/// leaves the failed state).
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;
  final Set<int> _retrying = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await ApiService.getFailedGenerationJobs();
      if (!mounted) return;
      setState(() { _jobs = jobs; _loading = false; _error = null; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not load failed jobs.'; _loading = false; });
    }
  }

  Future<void> _retry(int jobId) async {
    setState(() => _retrying.add(jobId));
    try {
      await ApiService.retryGenerationJob(jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job $jobId requeued')));
      await _load();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _retrying.remove(jobId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(92),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: ContentHead(eyebrow: 'Generations that need a retry', title: 'Failed resumes'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Ui.muted)))
              : _jobs.isEmpty
                  ? const Center(
                      child: Text('No failed jobs — all clear.',
                          style: TextStyle(color: Ui.muted)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _jobs.length,
                        itemBuilder: (context, index) =>
                            _buildCard(_jobs[index]),
                      ),
                    ),
    );
  }

  Widget _buildCard(Map<String, dynamic> job) {
    final jobId = job['job_id'] as int;
    final busy = _retrying.contains(jobId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Ui.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Job #$jobId · user ${job['user_id']} · template ${job['template_id']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: busy ? null : () => _retry(jobId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary))
                      : const Text('Retry', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job['error']?.toString() ?? 'No error recorded',
            style: const TextStyle(
                color: Ui.bad, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Failed at: ${job['finished_at'] ?? '—'}',
            style: const TextStyle(color: Ui.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
