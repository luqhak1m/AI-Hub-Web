import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';

/// A template's rendered preview image, fetched from the API with auth.
/// Shows a neutral grey box while loading and a document icon when the
/// template has no preview or the fetch fails.
class TemplatePreviewImage extends StatefulWidget {
  final String? previewPath;
  final BoxFit fit;
  final Alignment alignment;

  const TemplatePreviewImage({
    super.key,
    required this.previewPath,
    this.fit = BoxFit.cover,
    // Resumes lead with the header, so crop from the top when covering.
    this.alignment = Alignment.topCenter,
  });

  @override
  State<TemplatePreviewImage> createState() => _TemplatePreviewImageState();
}

class _TemplatePreviewImageState extends State<TemplatePreviewImage> {
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TemplatePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewPath != widget.previewPath) _load();
  }

  void _load() {
    final path = widget.previewPath;
    _future = path != null ? ApiService.getTemplatePreview(path) : null;
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) return _placeholder();
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit,
            alignment: widget.alignment,
            width: double.infinity,
            gaplessPlayback: true,
          );
        }
        if (snapshot.hasError) return _placeholder();
        return Container(color: const Color(0xFFEEEEEE));
      },
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFEEEEEE),
        alignment: Alignment.center,
        child: const Icon(Icons.description_outlined,
            color: Color(0xFFBBBBBB), size: 28),
      );
}
