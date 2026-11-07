import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/models/profile_model.dart';
import 'package:aidvise_platform/user/models/template_model.dart';
import 'package:aidvise_platform/user/widgets/template_preview_image.dart';
import 'package:aidvise_platform/user/screens/resume_loading_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

class TemplateCatalogScreen extends StatefulWidget {
  final ProfileModel profile;
  final String? jobTitle;
  final String? jobDescription;
  final String? company;
  /// When set, an application to this listing is submitted automatically
  /// after the resume is generated.
  final int? applyListingId;
  const TemplateCatalogScreen({
    super.key,
    required this.profile,
    this.jobTitle,
    this.jobDescription,
    this.company,
    this.applyListingId,
  });

  @override
  State<TemplateCatalogScreen> createState() => _TemplateCatalogScreenState();
}

class _TemplateCatalogScreenState extends State<TemplateCatalogScreen> {
  List<TemplateModel> _templates = [];
  int? _recommendedId;
  int? _selectedId;
  bool _loading = true;
  bool _recommending = false;
  String? _error;

  Map<String, int> get _userCounts => {
    'experience': widget.profile.experiences.length,
    'skills': widget.profile.skills.length,
    'education': widget.profile.education.length,
    'certifications': widget.profile.certifications.length,
  };

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final data = await ApiService.getEligibleTemplates();
      final parsed = data.map((t) => TemplateModel.fromJson(t)).toList();
      if (!mounted) return;
      setState(() {
        _templates = parsed;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Could not load templates: $e'; _loading = false; });
    }
  }

  Future<void> _recommend() async {
    setState(() => _recommending = true);
    try {
      final ids = _templates.map((t) => t.id).toList();
      final result = await ApiService.recommendTemplate(ids);
      setState(() => _recommendedId = result['recommended_template_id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recommended: ${result['reasoning']}'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recommendation failed: $e'), backgroundColor: AppTheme.primary),
        );
      }
    } finally {
      if (mounted) setState(() => _recommending = false);
    }
  }

  void _generate() {
    if (_selectedId == null) return;
    Navigator.of(context).pushReplacement(
      AppPageRoute(
        builder: (_) => ResumeLoadingScreen(
          templateId: _selectedId!,
          jobTitle: widget.jobTitle,
          jobDescription: widget.jobDescription,
          company: widget.company,
          applyListingId: widget.applyListingId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Choose a Template', style: TextStyle(color: AppTheme.primary)),
        actions: [
          if (_templates.isNotEmpty)
            TextButton(
              onPressed: _recommending ? null : _recommend,
              child: _recommending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                    )
                  : const Text('Recommend for me', style: TextStyle(color: AppTheme.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF233C))))
              : Column(children: [
                  if (widget.jobTitle != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tailoring your resume to: ${widget.jobTitle}',
                              style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _templates.length,
                      itemBuilder: (_, i) {
                        final t = _templates[i];
                        final isSelected = _selectedId == t.id;
                        final isRecommended = _recommendedId == t.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedId = t.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppTheme.cardShadow,
                              border: isSelected
                                  ? Border.all(color: AppTheme.primary, width: 1.5)
                                  : null,
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 62,
                                  height: 88,
                                  child: TemplatePreviewImage(
                                    previewPath: t.previewImageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Text(
                                      t.name,
                                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                                    ),
                                    if (isRecommended) ...[
                                      const SizedBox(width: 8),
                                      const Text(
                                        'recommended',
                                        style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ]),
                                  const SizedBox(height: 4),
                                  Text(t.description, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                                  Builder(builder: (_) {
                                    final hint = t.eligibilityHint(_userCounts);
                                    if (hint.isEmpty) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(hint, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                                    );
                                  }),
                                ]),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppTheme.primary),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.primary, width: 0.5)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _selectedId == null ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          disabledBackgroundColor: const Color(0xFFCCCCCC),
                        ),
                        child: const Text('Generate Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ]),
    );
  }
}
