import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/user/models/profile_model.dart';
import 'package:aidvise_platform/user/screens/profile_setup_screen.dart';
import 'package:aidvise_platform/user/screens/resume_pdf_screen.dart';
import 'package:aidvise_platform/user/screens/template_catalog_screen.dart';

/// Resumes — draft "Data table": this month's quota, then every generated
/// resume as a row.
class ResumesPage extends StatefulWidget {
  const ResumesPage({super.key});

  @override
  State<ResumesPage> createState() => _ResumesPageState();
}

class _ResumesPageState extends State<ResumesPage> {
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _quota; // {used, limit}
  String _query = '';
  bool _loading = true;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([ApiService.getResumeHistory(), ApiService.getMe(refresh: true)]);
      if (!mounted) return;
      setState(() {
        _history = (results[0] as List).cast<Map<String, dynamic>>();
        _quota = ((results[1] as Map)['limits'] as Map?)?['resume_generations_per_month'] as Map<String, dynamic>?;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your resumes.'; _loading = false; });
    }
  }

  /// Generating needs a profile: open the template picker, or the profile
  /// form first when there isn't one yet.
  Future<void> _generate() async {
    setState(() => _opening = true);
    try {
      final profile = ProfileModel.fromJson(await ApiService.getProfile());
      if (!mounted) return;
      await Navigator.of(context).push(AppPageRoute(builder: (_) => TemplateCatalogScreen(profile: profile)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        await Navigator.of(context).push(AppPageRoute(builder: (_) => const ProfileSetupScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    _load();
  }

  static bool _tailored(Map<String, dynamic> r) => ((r['company_name'] as String?) ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final used = _quota?['used'] as int? ?? 0;
    final limit = _quota?['limit'] as int?;
    final rows = _history.where((r) {
      if (_query.isEmpty) return true;
      final hay = '${r['company_name'] ?? ''} ${r['template_name'] ?? ''}'.toLowerCase();
      return hay.contains(_query.toLowerCase());
    }).toList();

    return UiState(
      loading: _loading,
      error: _error,
      onRetry: _load,
      builder: () => UiPage(children: [
        ContentHead(
          eyebrow: limit == null ? 'Unlimited generations' : '$used of $limit generations used this month',
          title: 'Resumes',
          titleSize: Ui.step2,
          actions: [
            SizedBox(
              width: 220,
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                style: context.ui.body(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search',
                  hintStyle: context.ui.body(color: context.ui.muted),
                  filled: true,
                  fillColor: context.ui.surface,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Ui.radiusSm), borderSide: BorderSide(color: context.ui.line)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Ui.radiusSm)),
                ),
              ),
            ),
            UiButton('Generate resume', busy: _opening, onPressed: _generate),
          ],
        ),
        StatsRow([
          ('Resumes', '${_history.length}'),
          ('Left this month', limit == null ? '∞' : '${(limit - used).clamp(0, limit)}'),
          ('Templates used', '${_history.map((r) => r['template_name']).toSet().length}'),
        ]),
        if (rows.isEmpty)
          Panel(child: Text(_history.isEmpty ? 'No resumes yet. Generate your first one.' : 'No resumes match.',
              style: context.ui.body(color: context.ui.muted)))
        else
          UiTable(
            columns: const ['Resume', 'For', 'Template', 'Created', 'Type'],
            rows: [
              for (final r in rows)
                UiTableRow(
                  [
                    Text(_tailored(r) ? 'Tailored resume' : 'General resume',
                        style: context.ui.body(weight: FontWeight.w700)),
                    Text(_tailored(r) ? r['company_name'] as String : 'No job selected'),
                    Text(r['template_name'] as String? ?? 'Template #${r['template_id']}'),
                    Text(shortDate(r['created_at'] as String?), style: context.ui.meta.copyWith(fontFeatures: Ui.tabular)),
                    Pill(_tailored(r) ? 'Tailored' : 'General', tone: _tailored(r) ? Tone.brand : Tone.plain),
                  ],
                  onTap: () => Navigator.of(context).push(AppPageRoute(
                    builder: (_) => ResumePdfScreen(
                        resumeId: r['id'] as int, pdfUrl: r['pdf_url'] as String? ?? '', viewerOnly: true),
                  )),
                ),
            ],
          ),
      ]),
    );
  }
}
