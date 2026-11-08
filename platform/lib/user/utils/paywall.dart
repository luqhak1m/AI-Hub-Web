import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/user/screens/subscription_screen.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Shows the upgrade dialog for quota-exhausted (402) responses.
/// Returns true if the exception was a 402 and was handled here.
bool handleUpgradeRequired(BuildContext context, ApiException e) {
  if (e.statusCode != 402) return false;
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.workspace_premium_outlined, size: 22, color: AppTheme.primary),
          SizedBox(width: 8),
          Text('Limit reached',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: Text(e.message,
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: Ui.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Not now', style: TextStyle(color: Ui.muted)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).push(
              AppPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white, elevation: 0),
          child: const Text('Upgrade to Pro'),
        ),
      ],
    ),
  );
  return true;
}
