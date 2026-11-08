import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/components.dart';
import 'package:aidvise_platform/shared/ui/layout.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/admin/admin_page.dart';

/// Admin user directory: find an account, then change its plan, reset its
/// password, or suspend it.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with AdminPagedList<AdminUsersScreen> {
  String? _query;
  String? _role;

  @override
  Future<Map<String, dynamic>> fetchPage(int skip, int limit) =>
      ApiService.getAdminUsers(query: _query, role: _role, skip: skip, limit: limit);

  @override
  String get loadError => 'Could not load users.';

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Users',
      searchHint: 'Search by name, username or company',
      onSearch: (q) { _query = q.trim(); load(); },
      filters: AdminFilterChips<String>(
        options: const [(null, 'All'), ('user', 'Job seekers'), ('vendor', 'Employers'), ('admin', 'Admins')],
        selected: _role,
        onSelected: (r) { _role = r; load(); },
      ),
      body: AdminListState(
        loading: loading,
        error: error,
        empty: items.isEmpty,
        emptyText: 'No users match.',
        onRetry: load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: pagedChildren('account', [
            // Draft "Data table": one row per account.
            UiTable(
              columns: const ['Name', 'Username', 'Type', 'Plan / company', 'Status'],
              rows: [
                for (final u in items)
                  UiTableRow(
                    [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        UiAvatar((u['full_name'] as String?)?.isNotEmpty == true
                            ? u['full_name'] as String
                            : u['username'] as String, size: 28),
                        const SizedBox(width: 10),
                        Text((u['full_name'] as String?)?.isNotEmpty == true
                            ? u['full_name'] as String
                            : u['username'] as String, style: Ui.body(weight: FontWeight.w600)),
                      ]),
                      Text('@${u['username']}', style: Ui.meta),
                      Pill(switch (u['role']) { 'admin' => 'Admin', 'vendor' => 'Employer', _ => 'Job seeker' },
                          tone: u['role'] == 'admin' ? Tone.brand : Tone.plain),
                      Text(u['role'] == 'vendor'
                          ? '${u['company_name'] ?? '—'} (${u['vendor_status']})'
                          : '${(u['tier'] as String? ?? 'free')[0].toUpperCase()}${(u['tier'] as String? ?? 'free').substring(1)} plan'),
                      u['is_active'] == false
                          ? const Pill('Deactivated', tone: Tone.bad)
                          : const Pill('Active', tone: Tone.good),
                    ],
                    onTap: () => _openUser(u['id'] as int),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }


  Future<void> _openUser(int userId) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UserDialog(userId: userId),
    );
    if (updated != null) replaceItem(updated);
  }
}

/// One account's details and the actions an admin can take on it.
class _UserDialog extends StatefulWidget {
  final int userId;
  const _UserDialog({required this.userId});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _plans = [];
  String? _error;
  bool _working = false;
  Map<String, dynamic>? _changed; // returned to the list on close

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getAdminUser(widget.userId),
        ApiService.getAdminPlans(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as Map<String, dynamic>;
        _plans = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<Map<String, dynamic>?> Function() action, String success) async {
    setState(() => _working = true);
    final result = await runAdminAction(context, action, success: success);
    if (!mounted) return;
    setState(() => _working = false);
    if (result != null) {
      _changed = result;
      await _load();
    }
  }

  Future<void> _changePlan() async {
    final user = _user!;
    String tier = user['tier'] as String;
    DateTime? expires;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Change plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: tier,
                decoration: adminInputDecoration('Plan'),
                items: [
                  for (final p in _plans)
                    DropdownMenuItem(value: p['key'] as String, child: Text(p['name'] as String)),
                ],
                onChanged: (v) => setDialog(() => tier = v ?? tier),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Text(
                    expires == null
                        ? 'No end date'
                        : 'Ends ${MaterialLocalizations.of(dialogContext).formatMediumDate(expires!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) setDialog(() => expires = picked);
                  },
                  child: Text(expires == null ? 'Set end date' : 'Change'),
                ),
                if (expires != null)
                  TextButton(onPressed: () => setDialog(() => expires = null), child: const Text('Clear')),
              ]),
              const Text(
                'Use this for complimentary or business accounts. People who pay '
                'through the App Store or Google Play are managed by their subscription.',
                style: TextStyle(fontSize: 12, color: Ui.muted, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => ApiService.setUserTierAdmin(widget.userId, tier, expiresAt: expires), 'Plan updated');
  }

  Future<void> _resetPassword() async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reset password'),
        content: TextField(
          controller: ctrl,
          decoration: adminInputDecoration('New password',
              helper: 'At least 8 characters. Share it with the user privately; they can change it after logging in.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (password == null || !mounted) return;
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 8 characters.')));
      return;
    }
    await _run(() async {
      await ApiService.resetUserPasswordAdmin(widget.userId, password);
      return null; // nothing on the card changes
    }, 'Password reset');
  }

  Future<void> _toggleActive() async {
    final active = _user!['is_active'] == true;
    final ok = await confirmAdminAction(
      context,
      title: active ? 'Deactivate account?' : 'Reactivate account?',
      message: active
          ? 'They will be signed out and unable to log in. Their data is kept, '
              'and you can reactivate the account at any time.'
          : 'They will be able to log in again.',
      confirmLabel: active ? 'Deactivate' : 'Reactivate',
      danger: active,
    );
    if (!ok || !mounted) return;
    await _run(() => ApiService.setUserActiveAdmin(widget.userId, !active),
        active ? 'Account deactivated' : 'Account reactivated');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(user == null ? 'User' : (user['full_name'] as String?) ?? user['username'] as String),
      content: SizedBox(
        width: 460,
        child: _error != null
            ? Text(_error!)
            : user == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                : SingleChildScrollView(child: _details(user)),
      ),
      actions: [
        if (user != null) ...[
          TextButton(onPressed: _working ? null : _resetPassword, child: const Text('Reset password')),
          if (user['role'] != 'vendor')
            TextButton(onPressed: _working ? null : _changePlan, child: const Text('Change plan')),
          TextButton(
            onPressed: _working ? null : _toggleActive,
            style: TextButton.styleFrom(
                foregroundColor: user['is_active'] == true ? AppTheme.danger : AppTheme.primary),
            child: Text(user['is_active'] == true ? 'Deactivate' : 'Reactivate'),
          ),
        ],
        TextButton(onPressed: () => Navigator.of(context).pop(_changed), child: const Text('Close')),
      ],
    );
  }

  Widget _details(Map<String, dynamic> user) {
    final usage = user['usage'] as Map<String, dynamic>;
    final limits = (usage['limits'] as Map<String, dynamic>);
    String date(String? iso) => iso == null
        ? 'never'
        : MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(iso).toLocal());
    final rows = <(String, String)>[
      ('Username', '@${user['username']}'),
      ('Status', user['is_active'] == true ? 'Active' : 'Deactivated'),
      ('Account type', switch (user['role']) { 'admin' => 'Admin', 'vendor' => 'Employer', _ => 'Job seeker' }),
      if (user['company_name'] != null) ('Company', '${user['company_name']} (${user['vendor_status']})'),
      if (user['email'] != null) ('Email', user['email'] as String),
      if (user['phone'] != null) ('Phone', user['phone'] as String),
      ('Plan', '${usage['tier_label']}${user['tier_expires_at'] != null ? ', ends ${date(user['tier_expires_at'] as String?)}' : ''}'),
      for (final e in limits.entries)
        (adminMetricLabel(e.key), '${e.value['used']} used of ${e.value['limit'] ?? 'unlimited'}'),
      ('Resumes', '${user['resume_count']}'),
      ('Applications', '${user['application_count']}'),
      if (user['role'] == 'vendor') ('Job listings', '${user['listing_count']}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Ui.muted, fontSize: 13))),
              Expanded(child: Text(value, style: const TextStyle(color: AppTheme.primary, fontSize: 13))),
            ]),
          ),
      ],
    );
  }
}
