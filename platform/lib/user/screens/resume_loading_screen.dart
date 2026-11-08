import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/screens/resume_pdf_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/user/utils/paywall.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

class ResumeLoadingScreen extends StatefulWidget {
  final int templateId;
  final String? jobTitle;
  final String? jobDescription;
  final String? company;
  /// When set, the PDF review screen shows a confirm-apply step for this
  /// listing — the application is only sent after the user has seen the
  /// generated resume and explicitly confirmed.
  final int? applyListingId;
  /// Skip the server-side result cache and generate fresh.
  final bool force;
  const ResumeLoadingScreen({
    super.key,
    required this.templateId,
    this.jobTitle,
    this.jobDescription,
    this.company,
    this.applyListingId,
    this.force = false,
  });

  @override
  State<ResumeLoadingScreen> createState() => _ResumeLoadingScreenState();
}

class _ResumeLoadingScreenState extends State<ResumeLoadingScreen> {
  // One key per generation attempt: if the request times out client-side
  // and this screen retries, the server replays instead of generating twice.
  final String _idempotencyKey = ApiService.newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  /// Polls the job every 2s until it finishes (up to 3 minutes).
  Future<Map<String, dynamic>> _pollUntilDone(int jobId) async {
    const interval = Duration(seconds: 2);
    const maxAttempts = 90;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(interval);
      if (!mounted) throw const ApiException(499, 'Cancelled');
      final job = await ApiService.getGenerationJob(jobId);
      final status = job['status'] as String;
      if (status == 'done') return job;
      if (status == 'failed') {
        throw ApiException(500, (job['error'] as String?) ?? 'Generation failed. Please try again.');
      }
    }
    throw const ApiException(408, 'Generation is taking longer than expected. Check your resume history in a few minutes.');
  }

  Future<void> _generate() async {
    try {
      final enqueue = await ApiService.generateResume(
        widget.templateId,
        jobTitle: widget.jobTitle,
        jobDescription: widget.jobDescription,
        companyName: widget.company,
        idempotencyKey: _idempotencyKey,
        force: widget.force,
      );
      // Server-side result cache: unchanged profile+template+job returns the
      // existing resume instantly (status done, no job queued) — skip polling.
      final result = enqueue['status'] == 'done'
          ? enqueue
          : await _pollUntilDone(enqueue['job_id'] as int);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppPageRoute(builder: (_) => ResumePdfScreen(
          resumeId: result['resume_id'] as int,
          pdfUrl: result['pdf_url'] as String,
          applyListingId: widget.applyListingId,
          applyJobTitle: widget.jobTitle,
          regenTemplateId: widget.templateId,
          regenJobTitle: widget.jobTitle,
          regenJobDescription: widget.jobDescription,
        )),
      );
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      if (handleUpgradeRequired(context, e)) {
        Navigator.of(context).pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.primary),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resume generation failed: $e'), backgroundColor: AppTheme.primary),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 20),
          Text('Building your resume...', style: TextStyle(color: AppTheme.primary, fontSize: 15)),
          SizedBox(height: 8),
          Text('This takes about 10–15 seconds', style: TextStyle(color: Ui.muted, fontSize: 13)),
        ]),
      ),
    );
  }
}
