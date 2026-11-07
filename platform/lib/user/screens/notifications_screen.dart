import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/user/screens/my_applications_screen.dart';
import 'package:aidvise_platform/user/screens/interview_prep_screen.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/shared/widgets/detail_sheet.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Notification center tab: application status updates, newest first.
/// A notification is marked read when the user opens it — not on arrival —
/// so the badge reflects what has actually been seen.
class NotificationsScreen extends StatefulWidget {
  /// Reports the remaining unread count so the shell's badge stays in step.
  final ValueChanged<int>? onUnreadChanged;

  /// Shown as a back arrow when this screen is a tab root (nothing to pop).
  final VoidCallback? onBack;
  const NotificationsScreen({super.key, this.onUnreadChanged, this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  static const _typeIcons = {
    'status': Icons.work_outline,
    'reschedule': Icons.schedule_send,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getNotifications();
      final notifications = ((data['notifications'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>();
      setState(() { _notifications = notifications; _loading = false; });
      // Reading is opening a notification, not landing on this tab, so the
      // badge only changes when the user actually opens something.
      widget.onUnreadChanged?.call((data['unread'] as num? ?? 0).toInt());
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load notifications.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Row(
              children: [
                if (widget.onBack != null) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppTheme.primary, size: 26),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 12),
                ],
                const Text(
                  'Notifications',
                  style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_notifications.any((n) => n['read'] == false))
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Mark all read',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? _buildError()
                    : _notifications.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _notifications.length,
                              itemBuilder: (_, i) => _buildItem(_notifications[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  elevation: 0),
              child: const Text('Retry'),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 40, color: Color(0xFFCCCCCC)),
              SizedBox(height: 12),
              Text('Nothing yet.',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
              SizedBox(height: 6),
              Text('Updates about your applications will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _buildItem(Map<String, dynamic> notification) {
    final unread = notification['read'] == false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        compact: true,
        highlighted: unread,
        icon: _typeIcons[notification['type']] ?? Icons.notifications_none,
        title: notification['title'] as String? ?? '',
        titleMeta: _relativeTime(notification['created_at'] as String?),
        onTap: () => _openDetail(notification),
      ),
    );
  }

  /// Where a notification leads. The server sends the destination, so the app
  /// never infers it from the notification's wording or type.
  ({String label, IconData icon, VoidCallback go})? _destination(
      Map<String, dynamic> notification) {
    final target = notification['target'] as Map<String, dynamic>?;
    if (target == null) return null;
    final applicationId = target['application_id'] as int?;

    if (target['screen'] == 'interview_prep' && applicationId != null) {
      return (
        label: 'View interview',
        icon: Icons.event_available,
        go: () => Navigator.of(context).push(
              AppPageRoute(
                builder: (_) => InterviewPrepScreen(applicationId: applicationId),
              ),
            ),
      );
    }
    return (
      label: 'View application',
      icon: Icons.work_outline,
      go: () => Navigator.of(context).push(
            AppPageRoute(
              builder: (_) => MyApplicationsScreen(
                  initialStatus: target['status'] as String?),
            ),
          ),
    );
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    if (notification['read'] == true) return;
    final id = notification['id'] as int?;
    if (id == null) return;
    setState(() => notification['read'] = true); // optimistic
    try {
      final remaining = await ApiService.markNotificationRead(id);
      widget.onUnreadChanged?.call(remaining);
    } catch (_) {
      if (mounted) setState(() => notification['read'] = false); // roll back
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService.markNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in _notifications) {
          n['read'] = true;
        }
      });
      widget.onUnreadChanged?.call(0);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
    } catch (_) {}
  }

  void _openDetail(Map<String, dynamic> notification) {
    _markRead(notification);
    final destination = _destination(notification);
    showDetailSheet(
      context,
      title: notification['title'] as String? ?? '',
      meta: _relativeTime(notification['created_at'] as String?),
      initialSize: 0.45,
      sections: [
        DetailSection(
          title: 'Details',
          icon: Icons.notifications_none,
          child: Text(
            notification['body'] as String? ?? '',
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 14, height: 1.55),
          ),
        ),
      ],
      actionLabel: destination?.label,
      actionIcon: destination?.icon,
      onAction: destination?.go,
    );
  }

  static String _relativeTime(String? iso) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
