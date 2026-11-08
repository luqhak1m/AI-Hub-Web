import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/models/profile_model.dart';
import 'package:aidvise_platform/user/screens/template_catalog_screen.dart';
import 'package:aidvise_platform/user/screens/profile_setup_screen.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Entry point for applying to a job: lets the user choose between
/// generating a tailored resume (AI flow, confirm before sending) or
/// uploading their own PDF (applies immediately).
///
/// The returned future resolves when the flow finishes, so callers can
/// refresh their applied-state.
Future<void> applyToJob(BuildContext context, Map<String, dynamic> job) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apply to ${job['title'] ?? 'this job'}',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            _ApplyOption(
              icon: Icons.auto_awesome,
              title: 'Generate Tailored Resume',
              subtitle: 'AI writes a resume tailored to this job. You review it before the application is sent.',
              onTap: () => Navigator.of(sheetContext).pop('tailored'),
            ),
            const SizedBox(height: 10),
            _ApplyOption(
              icon: Icons.upload_file_outlined,
              title: 'Upload My Own Resume',
              subtitle: 'Attach a PDF from your device and apply right away.',
              onTap: () => Navigator.of(sheetContext).pop('upload'),
            ),
          ],
        ),
      ),
    ),
  );

  if (choice == 'tailored') {
    if (context.mounted) await applyWithTailoredResume(context, job);
  } else if (choice == 'upload') {
    if (context.mounted) await applyWithUpload(context, job);
  }
}

class _ApplyOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ApplyOption({
    required this.icon, required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Ui.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Ui.muted, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Ui.muted),
          ],
        ),
      ),
    );
  }
}

/// Upload path: pick a PDF, send it with the application immediately.
/// The web job page offers it as its own button.
Future<void> applyWithUpload(BuildContext context, Map<String, dynamic> job) async {
  final listingId = job['id'] as int?;
  if (listingId == null) return;

  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true, // web gives bytes, never a path
  );
  final bytes = picked?.files.single.bytes;
  if (bytes == null || !context.mounted) return; // cancelled

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
  );
  try {
    await ApiService.applyWithUploadedResume(
      listingId: listingId,
      bytes: bytes,
      fileName: picked!.files.single.name,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application submitted with your resume!'),
        backgroundColor: AppTheme.primary,
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted && handleSessionExpiry(context, e)) return;
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.statusCode == 409 ? 'You already applied to this job.' : e.message)));
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload failed. Try again.')),
    );
  }
}

/// Tailored path: profile -> template selection -> generation -> review ->
/// confirm-apply on the PDF screen.
Future<void> applyWithTailoredResume(BuildContext context, Map<String, dynamic> job) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
  );
  try {
    final data = await ApiService.getProfile();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
    final profile = ProfileModel.fromJson(data);
    final jobTitle = job['title'] as String? ?? '';
    final company = job['company'] as String? ?? '';
    final desc = job['description'] as String? ?? '';
    final jobDescription = company.isNotEmpty ? '$jobTitle at $company. $desc' : desc;
    await Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => TemplateCatalogScreen(
          profile: profile,
          jobTitle: jobTitle,
          jobDescription: jobDescription,
          company: company.isEmpty ? null : company,
          applyListingId: job['id'] as int?,
        ),
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted && handleSessionExpiry(context, e)) return;
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
    if (e.statusCode == 404) {
      // No profile yet — send them to create one first
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create your profile first to generate a tailored resume.')),
      );
      Navigator.of(context).push(
        AppPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Something went wrong. Try again.')),
    );
  }
}
