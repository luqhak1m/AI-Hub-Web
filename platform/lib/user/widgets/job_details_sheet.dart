import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/detail_sheet.dart';

/// Slide-up job details: full description, required skills, and applying.
/// Shared by Browse Jobs, Matched Jobs, and My Applications so every place
/// shows the same job the same way.
Future<void> showJobDetailsSheet(
  BuildContext context,
  Map<String, dynamic> job, {
  /// Runs the apply flow for this job. Omit to show the sheet read-only.
  Future<void> Function()? onApply,
}) {
  final skills = ((job['required_skills'] as List<dynamic>?) ?? [])
      .map((s) => s.toString())
      .where((s) => s.isNotEmpty)
      .toList();
  final location = job['location'] as String? ?? '';
  final salary = job['salary'] as String? ?? '';
  final type = job['type'] as String? ?? '';
  final family = job['occupation'] as String? ?? '';
  final posted = job['posted'] as String? ?? '';
  final applied = job['applied'] == true;

  return showDetailSheet(
    context,
    title: job['title'] as String? ?? '',
    subtitle: job['company'] as String?,
    initialSize: 0.7,
    headerExtras: [
      if (location.isNotEmpty) ...[
        const SizedBox(height: 10),
        _iconLine(Icons.location_on_outlined, location),
      ],
      if (salary.isNotEmpty) ...[
        const SizedBox(height: 4),
        _iconLine(Icons.payments_outlined, salary),
      ],
      if (type.isNotEmpty || family.isNotEmpty || posted.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (type.isNotEmpty) _tag(type),
            if (family.isNotEmpty) _tag(family),
            if (posted.isNotEmpty) _tag(posted),
          ],
        ),
      ],
    ],
    sections: [
      DetailSection(
        title: 'Job description',
        icon: Icons.description_outlined,
        child: Text(
          job['description'] as String? ?? '',
          style: const TextStyle(
              color: AppTheme.primary, fontSize: 14, height: 1.55),
        ),
      ),
      if (skills.isNotEmpty)
        DetailSection(
          title: 'Required skills',
          icon: Icons.workspace_premium_outlined,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final skill in skills) _skillChip(skill)],
          ),
        ),
    ],
    actionLabel: (onApply != null || applied)
        ? (applied ? 'Applied' : 'Apply with Tailored Resume')
        : null,
    actionIcon: applied ? Icons.check : Icons.send_outlined,
    actionEnabled: !applied,
    onAction: onApply,
  );
}

/// Variant for places that only know the listing id (e.g. an application):
/// fetches the full listing, then shows the same sheet.
Future<void> showJobDetailsSheetById(
  BuildContext context,
  int listingId, {
  Future<void> Function(Map<String, dynamic> job)? onApply,
}) async {
  try {
    final job = await ApiService.getJobListing(listingId);
    if (!context.mounted) return;
    await showJobDetailsSheet(
      context,
      job,
      onApply: onApply == null ? null : () => onApply(job),
    );
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load job details.')));
  }
}

Widget _iconLine(IconData icon, String text) => Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
        ),
      ],
    );

Widget _tag(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardHairline, width: 0.8),
      ),
      child: Text(label,
          style: const TextStyle(color: AppTheme.primary, fontSize: 11.5)),
    );

Widget _skillChip(String skill) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardGreyDeep,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(skill,
          style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
