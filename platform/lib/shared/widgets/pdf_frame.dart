import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Shows PDF bytes with the browser's own viewer (zoom, scroll, print),
/// which Chrome, Safari, Edge and Firefox all provide. Replaces the mobile
/// app's native PDF view, which has no web implementation.
class PdfFrame extends StatefulWidget {
  final Uint8List bytes;
  const PdfFrame({super.key, required this.bytes});

  @override
  State<PdfFrame> createState() => _PdfFrameState();
}

class _PdfFrameState extends State<PdfFrame> {
  static int _nextId = 0;
  late final String _viewType = 'pdf-frame-${_nextId++}';
  late final String _url;

  @override
  void initState() {
    super.initState();
    final blob = web.Blob([widget.bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
    _url = web.URL.createObjectURL(blob);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final frame = web.HTMLIFrameElement()
        ..src = _url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return frame;
    });
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_url); // the blob would otherwise live until the tab closes
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

/// Saves PDF bytes through the browser's download, reporting the outcome.
Future<void> savePdf(BuildContext context, Uint8List bytes, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await FileSaver.instance.saveFile(name: name, bytes: bytes, ext: 'pdf', mimeType: MimeType.pdf);
    messenger.showSnackBar(const SnackBar(
        content: Text('Resume downloaded'), backgroundColor: AppTheme.primary));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: AppTheme.primary));
  }
}
