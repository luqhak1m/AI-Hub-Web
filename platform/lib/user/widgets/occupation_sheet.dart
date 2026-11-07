import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/detail_sheet.dart';

/// What each RIASEC (Holland) dimension means, in plain language — used to
/// explain *why* a career path was recommended.
const _riasecMeanings = <String, String>{
  'Realistic':
      'You prefer hands-on work with tools, machines, or the physical world — '
          'building, repairing, and seeing tangible results.',
  'Investigative':
      'You enjoy analysing problems, working with ideas and data, and figuring '
          'out how things work before acting.',
  'Artistic':
      'You look for room to create and express — original work, design, and '
          'open-ended problems over fixed procedures.',
  'Social':
      'You are drawn to helping, teaching, and working directly with people, '
          'and you measure success partly by their progress.',
  'Enterprising':
      'You like leading, persuading, and driving outcomes — taking initiative '
          'and carrying commercial or organisational risk.',
  'Conventional':
      'You work well with structure, accuracy, and clear processes — order and '
          'reliable systems suit you.',
};

/// Slide-up explanation of one recommended career path: what the field is,
/// why it matched, and what each of its Holland dimensions means.
Future<void> showOccupationSheet(
  BuildContext context,
  Map<String, dynamic> occupation, {
  required int rank,
  VoidCallback? onAskAdvisor,
}) {
  final name = occupation['title'] as String? ?? '';
  final description = occupation['description'] as String? ?? '';
  final score = (occupation['match_score'] as num?)?.round();
  final holland = (occupation['holland_code'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>();
  final matched = holland.where((h) => h['matched'] == true).toList();
  final others = holland.where((h) => h['matched'] != true).toList();

  return showDetailSheet(
    context,
    title: '$rank. ${name.toUpperCase()}',
    meta: score != null ? '$score%' : null,
    initialSize: 0.75,
    headerExtras: [
      if (score != null) ...[
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your answers align $score% with the interest profile typical of '
          'this field.',
          style: const TextStyle(
              color: AppTheme.primary, fontSize: 13, height: 1.5),
        ),
      ],
    ],
    sections: [
      if (description.isNotEmpty)
        DetailSection(
          title: 'About this field',
          child: Text(
            description,
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 14, height: 1.55),
          ),
        ),
      if (matched.isNotEmpty)
        DetailSection(
          title: 'Why it matched you',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'These are the interest types you scored highly on that this '
                'field also calls for.',
                style: TextStyle(
                    color: Color(0xFF888888), fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 12),
              for (final entry in matched) _dimension(entry, matched: true),
            ],
          ),
        ),
      if (others.isNotEmpty)
        DetailSection(
          title: 'Also part of this field',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This field draws on these too — useful to know if you want '
                'to grow into it.',
                style: TextStyle(
                    color: Color(0xFF888888), fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 12),
              for (final entry in others) _dimension(entry, matched: false),
            ],
          ),
        ),
    ],
    actionLabel: onAskAdvisor == null ? null : 'Ask the advisor about $name',
    actionIcon: Icons.smart_toy_outlined,
    onAction: onAskAdvisor,
  );
}

Widget _dimension(Map<String, dynamic> entry, {required bool matched}) {
  final label = entry['label'] as String? ?? '';
  final meaning = _riasecMeanings[label] ?? '';
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      // White, so a dimension never reads as another section heading.
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.cardHairline, width: 0.8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: matched ? AppTheme.cardGreyDeep : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: matched
                        ? AppTheme.cardGreyDeep
                        : AppTheme.cardHairline),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11.5,
                  fontWeight: matched ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (matched) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, size: 15, color: AppTheme.primary),
              const SizedBox(width: 4),
              const Text('Strong for you',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        if (meaning.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            meaning,
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 13, height: 1.5),
          ),
        ],
      ],
    ),
  );
}
