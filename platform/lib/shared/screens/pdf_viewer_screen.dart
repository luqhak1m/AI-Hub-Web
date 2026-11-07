import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/pdf_frame.dart';

/// Read-only PDF page with a download button — e.g. an employer reading an
/// applicant's resume. Job seekers' own resumes use the resume screen, which
/// adds regenerate and apply actions.
class PdfViewerScreen extends StatefulWidget {
  final String title;
  final String pdfPath;
  final String downloadName;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfPath,
    required this.downloadName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.downloadPdf(widget.pdfPath).then(
      (bytes) { if (mounted) setState(() => _bytes = Uint8List.fromList(bytes)); },
      onError: (Object e) { if (mounted) setState(() => _error = e.toString()); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_bytes != null)
            IconButton(
              icon: const Icon(Icons.download, color: AppTheme.primary),
              tooltip: 'Download PDF',
              onPressed: () => savePdf(context, _bytes!, widget.downloadName),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
          : _bytes == null
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : PdfFrame(bytes: _bytes!),
    );
  }
}
