import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';
import 'package:aidvise_platform/user/pages/sections.dart';
import 'package:aidvise_platform/user/screens/interview_prep_screen.dart';

/// Notifications — draft "List + detail": updates on the left, the full
/// message and where it leads on the right. Opening one marks it read.
class NotificationsPage extends StatefulWidget {
  final OpenSection open;
  final ValueChanged<int> onUnreadChanged;
  const NotificationsPage({super.key, required this.open, required this.onUnreadChanged});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _icons = {'status': Icons.work_outline, 'reschedule': Icons.event_repeat};

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.getNotifications(refresh: true);
      if (!mounted) return;
      setState(() {
        _items = ((data['notifications'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
      widget.onUnreadChanged((data['unread'] as num? ?? 0).toInt());
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load notifications.'; _loading = false; });
    }
  }

  int get _unread => _items.where((n) => n['read'] == false).length;

  Future<void> _open(Map<String, dynamic> n) async {
    if (isNarrow(context)) {
      openDetailPage(context, n['title'] as String? ?? 'Notification', _detail(n));
    } else {
      setState(() => _selectedId = n['id'] as int?);
    }
    if (n['read'] == false && n['id'] != null) {
      setState(() => n['read'] = true);
      try {
        widget.onUnreadChanged(await ApiService.markNotificationRead(n['id'] as int));
      } catch (_) {
        if (mounted) setState(() => n['read'] = false);
      }
    }
  }

  Future<void> _markAll() async {
    try {
      await ApiService.markNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['read'] = true;
        }
      });
      widget.onUnreadChanged(0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final selected = _items.where((n) => n['id'] == _selectedId).firstOrNull;
    return UiPage(fill: true, children: [
      ContentHead(
        eyebrow: _loading ? null : '$_unread unread',
        title: 'Notifications',
        actions: [if (_unread > 0) UiButton('Mark all read', onPressed: _markAll)],
      ),
      Expanded(
        child: UiState(
          loading: _loading,
          error: _error,
          onRetry: _load,
          empty: _items.isEmpty,
          emptyText: 'Nothing yet. Updates about your applications appear here.',
          builder: () => UiListDetail(
            rows: [
              for (final n in _items)
                ListRow(
                  leading: IconTile(_icons[n['type']] ?? Icons.notifications_none),
                  title: n['title'] as String? ?? '',
                  sub: timeAgo(n['created_at'] as String?),
                  trailing: n['read'] == false ? const Pill('New', tone: Tone.warn) : null,
                  unread: n['read'] == false,
                  selected: !isNarrow(context) && n['id'] == _selectedId,
                  onTap: () => _open(n),
                ),
            ],
            detail: selected == null ? null : _detail(selected),
            emptyDetail: 'Select a notification to read it.',
          ),
        ),
      ),
    ]);
  }

  Widget _detail(Map<String, dynamic> n) {
    final target = n['target'] as Map<String, dynamic>?;
    final applicationId = target?['application_id'] as int?;
    final interview = target?['screen'] == 'interview_prep' && applicationId != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('Notification'),
      const SizedBox(height: 10),
      Row(children: [
        IconTile(_icons[n['type']] ?? Icons.notifications_none, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n['title'] as String? ?? '', style: context.ui.display(Ui.step3)),
            Text(timeAgo(n['created_at'] as String?), style: context.ui.meta),
          ]),
        ),
      ]),
      const SizedBox(height: 20),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(n['body'] as String? ?? '', style: context.ui.body(size: Ui.step1, color: context.ui.muted)),
      ),
      if (target != null) ...[
        const SizedBox(height: 20),
        UiButton(
          interview ? 'View interview' : 'View application',
          onPressed: () => interview
              ? Navigator.of(context).push(AppPageRoute(
                  builder: (_) => InterviewPrepScreen(applicationId: applicationId)))
              : widget.open(UserSection.applications),
        ),
      ],
    ]);
  }
}
