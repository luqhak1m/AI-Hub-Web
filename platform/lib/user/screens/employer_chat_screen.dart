import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Direct messaging with an employer. The screen and its entry points exist;
/// the messaging backend does not yet, so this shows the thread header and a
/// disabled composer until the chat service lands.
class EmployerChatScreen extends StatelessWidget {
  final String company;

  /// Kept so the future chat service can scope the thread to one application.
  final int applicationId;

  const EmployerChatScreen({
    super.key,
    required this.company,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: const Icon(Icons.business, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 44, color: Ui.surface3),
                    const SizedBox(height: 14),
                    const Text(
                      'Messaging is coming soon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You will be able to message $company here about your '
                      'interview. For now, use the details on the prep card.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Ui.muted, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: Ui.line, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'Messaging not available yet',
                      style: TextStyle(color: Ui.muted, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                      color: Ui.surface3, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
