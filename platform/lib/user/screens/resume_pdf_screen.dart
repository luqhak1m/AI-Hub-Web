import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/widgets/pdf_frame.dart';
import 'package:aidvise_platform/user/screens/resume_loading_screen.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

class ResumePdfScreen extends StatefulWidget {
  final int resumeId;
  final String pdfUrl;
  /// When set, the screen is the final step of an apply flow: the user
  /// reviews the generated resume, then explicitly confirms to submit the
  /// application to this listing with this resume attached.
  final int? applyListingId;
  final String? applyJobTitle;
  /// Viewer-only mode (e.g. a vendor reading an applicant's resume): no
  /// "Generate Another" action, neutral title.
  final bool viewerOnly;
  /// Generation inputs, present when arriving from the generate flow —
  /// enables the "regenerate fresh" toolbar action.
  final int? regenTemplateId;
  final String? regenJobTitle;
  final String? regenJobDescription;
  const ResumePdfScreen({
    super.key,
    required this.resumeId,
    required this.pdfUrl,
    this.applyListingId,
    this.applyJobTitle,
    this.viewerOnly = false,
    this.regenTemplateId,
    this.regenJobTitle,
    this.regenJobDescription,
  });

  @override
  State<ResumePdfScreen> createState() => _ResumePdfScreenState();
}

class _ResumePdfScreenState extends State<ResumePdfScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _saving = false;
  bool _applying = false;
  bool _applied = false;
  String? _error;

  @override
  void dispose() {
    // Apply flow abandoned without confirming: discard the tailored resume
    // so unconfirmed drafts don't pile up in the user's history. Fire and
    // forget — the server also refuses to delete anything an application
    // still references.
    if (widget.applyListingId != null && !_applied) {
      ApiService.deleteResume(widget.resumeId).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _confirmApply() async {
    if (_applying || _applied || widget.applyListingId == null) return;
    setState(() => _applying = true);
    try {
      await ApiService.submitJobApplication(
        widget.applyListingId!, resumeId: widget.resumeId);
      if (!mounted) return;
      setState(() => _applied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted! Track it under My Applications.'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        setState(() => _applied = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already applied to this job.'),
              backgroundColor: AppTheme.primary),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.primary),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit the application. Try again.'),
            backgroundColor: AppTheme.primary),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: (_applying || _applied) ? null : _confirmApply,
        icon: _applying
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_applied ? Icons.check_circle_outline : Icons.send, size: 18),
        label: Text(
          _applied
              ? 'Application Submitted'
              : 'Confirm & Apply${widget.applyJobTitle != null ? ' — ${widget.applyJobTitle}' : ''}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          disabledForegroundColor: const Color(0xFF888888),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    try {
      final bytes = await ApiService.downloadPdf(widget.pdfUrl);
      if (!mounted) return;
      setState(() { _bytes = Uint8List.fromList(bytes); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _saveToDevice() async {
    if (_bytes == null) return;
    setState(() => _saving = true);
    await savePdf(context, _bytes!, 'resume_${widget.resumeId}');
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.viewerOnly ? 'Applicant Resume' : 'Your Resume',
            style: const TextStyle(color: AppTheme.primary)),
        actions: [
          if (!widget.viewerOnly && widget.regenTemplateId != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primary),
              tooltip: 'Regenerate fresh (uses a generation credit)',
              onPressed: () => Navigator.of(context).pushReplacement(
                AppPageRoute(
                  builder: (_) => ResumeLoadingScreen(
                    templateId: widget.regenTemplateId!,
                    jobTitle: widget.regenJobTitle,
                    jobDescription: widget.regenJobDescription,
                    applyListingId: widget.applyListingId,
                    force: true,
                  ),
                ),
              ),
            ),
          if (!_loading && _error == null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                    )
                  : const Icon(Icons.download, color: AppTheme.primary),
              onPressed: _saving ? null : _saveToDevice,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF233C))))
              : Column(children: [
                      Expanded(child: PdfFrame(bytes: _bytes!)),
                      if (!widget.viewerOnly)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppTheme.primary, width: 0.5)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.applyListingId != null) ...[
                              _buildApplyButton(),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  widget.applyListingId != null ? 'Back to Jobs' : 'Generate Another',
                                  style: const TextStyle(color: AppTheme.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
    );
  }
}
