import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Ui.bad)))
              : Column(children: [
                  if (widget.jobTitle != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Ui.surface,
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
                  // A grid of full previews: on a wide screen people choose a
                  // template by looking at it.
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final cols = box.maxWidth < 560 ? 1 : box.maxWidth < 900 ? 2 : 3;
                      return GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _templates.length,
                        itemBuilder: (_, i) {
                          final t = _templates[i];
                          final isSelected = _selectedId == t.id;
                          final isRecommended = _recommendedId == t.id;
                          final hint = t.eligibilityHint(_userCounts);
                          return Panel(
                            onTap: () => setState(() => _selectedId = t.id),
                            padding: const EdgeInsets.all(12),
                            color: isSelected ? Ui.brandSoft : Ui.surface,
                            borderColor: isSelected ? Ui.brandFill : null,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Ui.surface,
                                    borderRadius: BorderRadius.circular(Ui.radiusSm),
                                    border: Border.all(color: Ui.line),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: TemplatePreviewImage(previewPath: t.previewImageUrl, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: Text(t.name, style: Ui.body(size: Ui.step1, weight: FontWeight.w700))),
                                if (isRecommended) const Pill('Recommended', tone: Tone.good),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle, size: 20, color: Ui.brandFill),
                                ],
                              ]),
                              const SizedBox(height: 2),
                              Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ui.meta),
                              if (hint.isNotEmpty) Text(hint, style: Ui.meta.copyWith(fontSize: 11)),
                            ]),
                          );
                        },
                      );
                    }),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Ui.surface,
                      border: Border(top: BorderSide(color: Ui.line)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(_selectedId == null ? 'Pick a template to continue' : 'Ready to generate',
                          style: Ui.meta),
                      const SizedBox(width: 14),
                      UiButton('Generate resume', onPressed: _selectedId == null ? null : _generate),
                    ]),
                  ),
                ]),
    );
  }
}
