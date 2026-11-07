import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Feedback dialog shared by the user and vendor profile tabs.
Future<void> showFeedbackDialog(BuildContext context) async {
  final messageCtrl = TextEditingController();
  String category = 'other';

  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [
                  ('bug', 'Bug'),
                  ('idea', 'Idea'),
                  ('other', 'Other'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: category == option.$1,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                        color: category == option.$1
                            ? Colors.white
                            : AppTheme.primary),
                    onSelected: (_) =>
                        setDialogState(() => category = option.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'What happened, or what would make this better?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send')),
        ],
      ),
    ),
  );

  if (submitted != true || !context.mounted) return;
  if (messageCtrl.text.trim().length < 3) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a little more detail')));
    return;
  }
  try {
    await ApiService.sendFeedback(
        category: category, message: messageCtrl.text.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — feedback sent!')));
  } on ApiException catch (e) {
    if (context.mounted && handleSessionExpiry(context, e)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
  }
}
