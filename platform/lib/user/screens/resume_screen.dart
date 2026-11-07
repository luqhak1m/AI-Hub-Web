import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/models/profile_model.dart';
import 'package:aidvise_platform/user/screens/profile_setup_screen.dart';
import 'package:aidvise_platform/user/screens/template_catalog_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/user/screens/resume_pdf_screen.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  ProfileModel? _profile;
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ApiService.getResumeHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {} // the list is a bonus — never block the generator
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getProfile();
      if (!mounted) return;
      setState(() { _profile = ProfileModel.fromJson(data); _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.statusCode == 404) {
        await Navigator.of(context).push(AppPageRoute(builder: (_) => const ProfileSetupScreen()));
        if (mounted) _loadProfile();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Resume Generator', style: TextStyle(color: AppTheme.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF888888)),
            tooltip: 'Edit profile',
            onPressed: () async {
              await Navigator.of(context).push(AppPageRoute(builder: (_) => const ProfileSetupScreen(isEditing: true)));
              if (mounted) _loadProfile();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${_profile?.name ?? 'there'}',
              style: const TextStyle(color: AppTheme.primary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${_profile?.experiences.length ?? 0} experiences · ${_profile?.skills.length ?? 0} skills · ${_profile?.education.length ?? 0} education',
              style: const TextStyle(color: Color(0xFF888888)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.description_outlined),
                label: const Text('Generate Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _profile == null
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          AppPageRoute(
                              builder: (_) =>
                                  TemplateCatalogScreen(profile: _profile!)),
                        );
                        _loadHistory(); // a new resume may have been generated
                      },
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Generated resumes',
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _history.isEmpty
                  ? const Text(
                      'No tailored resumes yet — generate your first one above.',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _history.length,
                      itemBuilder: (_, i) => _buildHistoryItem(_history[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> resume) {
    final id = resume['id'] as int;
    final pdfUrl = resume['pdf_url'] as String? ?? '';
    final company = (resume['company_name'] as String?)?.trim() ?? '';
    final template = (resume['template_name'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        compact: true,
        icon: Icons.picture_as_pdf,
        title: company.isNotEmpty ? company : 'General Resume',
        titleMeta: _formatDate(resume['created_at'] as String?),
        description:
            template.isNotEmpty ? template : 'Template #${resume['template_id']}',
        onTap: () => Navigator.of(context).push(
          AppPageRoute(
            builder: (_) => ResumePdfScreen(
                resumeId: id, pdfUrl: pdfUrl, viewerOnly: true),
          ),
        ),
      ),
    );
  }

  /// "2026-07-20T10:00:00" → "20 Jul"
  static String _formatDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
