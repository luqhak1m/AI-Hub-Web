import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/admin/admin_page.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';

/// Subscription plans: names, features, quotas and store prices. A price
/// change is sent to the App Store and Google Play by the server; the status
/// chip on each plan says whether the stores are charging it yet.
class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final plans = await ApiService.getAdminPlans();
      if (mounted) setState(() => _plans = plans);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load plans.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replace(Map<String, dynamic> plan) {
    final i = _plans.indexWhere((p) => p['key'] == plan['key']);
    if (i >= 0) setState(() => _plans[i] = plan);
  }

  Future<void> _checkNow() async {
    await runAdminAction(context, ApiService.checkPlanPricesAdmin,
        success: 'Checking the stores. Refresh in a minute to see the result.');
  }

  Future<void> _resend(Map<String, dynamic> plan) async {
    final updated = await runAdminAction(
        context, () => ApiService.resendPlanPricesAdmin(plan['key'] as String),
        success: 'Sending the prices to the stores again');
    if (updated != null) _replace(updated);
  }

  Future<void> _showStatus(Map<String, dynamic> plan) async {
    final status = plan['price_status'] as String?;
    final checked = plan['price_checked_at'] as String?;
    final resend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('${plan['name']}: ${_statusLabel(status)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan['price_status_message'] as String? ?? _statusExplainer(status),
                style: const TextStyle(fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 12),
            Text(
              checked == null
                  ? 'Not checked against the stores yet.'
                  : 'Last checked ${MaterialLocalizations.of(dialogContext).formatMediumDate(DateTime.parse(checked).toLocal())} '
                      'at ${TimeOfDay.fromDateTime(DateTime.parse(checked).toLocal()).format(dialogContext)}. '
                      'The stores are checked every hour.',
              style: const TextStyle(fontSize: 12, color: Ui.muted),
            ),
          ],
        ),
        actions: [
          if (status == 'failed')
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Send again')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Close')),
        ],
      ),
    );
    if (resend == true && mounted) await _resend(plan);
  }

  Future<void> _edit(Map<String, dynamic> plan) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PlanEditor(plan: plan),
    );
    if (updated != null) _replace(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Plans',
      actions: [
        TextButton.icon(
          onPressed: _checkNow,
          icon: const Icon(Icons.sync, color: AppTheme.primary),
          label: const Text('Check stores now', style: TextStyle(color: AppTheme.primary)),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ],
      body: AdminListState(
        loading: _loading,
        error: _error,
        empty: _plans.isEmpty,
        emptyText: 'No plans.',
        onRetry: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final p in _plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppCard(
                  icon: Icons.workspace_premium,
                  title: p['name'] as String,
                  details: [
                    if (p['app_store_product_id'] != null)
                      CardDetail(Icons.phone_iphone, 'App Store: ${formatPlanPrice(p, 'app_store_price')}'),
                    if (p['play_store_product_id'] != null)
                      CardDetail(Icons.android, 'Google Play: ${formatPlanPrice(p, 'play_store_price')}'),
                    for (final e in (p['limits'] as Map<String, dynamic>).entries)
                      CardDetail(Icons.speed, '${adminMetricLabel(e.key)}: ${e.value ?? 'Unlimited'}'),
                  ],
                  status: p['price_status'] == null ? null : _statusLabel(p['price_status'] as String?),
                  statusIcon: _statusIcon(p['price_status'] as String?),
                  onStatusTap: () => _showStatus(p),
                  onTap: () => _edit(p),
                ),
              ),
            const Text(
              'Tap a plan to edit it. Price changes apply to new subscribers; '
              'people already subscribed keep their current price.',
              style: TextStyle(color: Ui.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String? status) => switch (status) {
        'synced' => 'Prices live',
        'pending' => 'Waiting for stores',
        'failed' => 'Needs attention',
        _ => 'Not sold in stores',
      };

  static String _statusExplainer(String? status) => switch (status) {
        'synced' => 'Both stores are charging the prices shown.',
        'pending' => 'The new price was sent. Stores can take up to a day to apply it.',
        'failed' => 'A store did not accept the price.',
        _ => 'This plan has no store products.',
      };

  static IconData? _statusIcon(String? status) => switch (status) {
        'synced' => Icons.check_circle_outline,
        'pending' => Icons.schedule,
        'failed' => Icons.error_outline,
        _ => null,
      };
}

/// "RM 9.90", or "Not set".
String formatPlanPrice(Map<String, dynamic> plan, String field) {
  final value = plan[field] as num?;
  if (value == null) return 'Not set';
  final currency = plan['currency'] as String? ?? 'MYR';
  return '${currency == 'MYR' ? 'RM' : currency} ${value.toStringAsFixed(2)}';
}

/// Full editor for one plan. Sends only the fields that changed, and asks
/// for confirmation before a price change goes to the stores.
class _PlanEditor extends StatefulWidget {
  final Map<String, dynamic> plan;
  const _PlanEditor({required this.plan});

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final TextEditingController _name, _description, _features;
  late final TextEditingController _appId, _appPrice, _playId, _playBase, _playPrice;
  final Map<String, TextEditingController> _limits = {};
  final Map<String, bool> _unlimited = {};
  bool _saving = false;
  String? _error;

  Map<String, dynamic> get _plan => widget.plan;

  @override
  void initState() {
    super.initState();
    String text(String key) => (_plan[key] ?? '').toString();
    String price(String key) => (_plan[key] as num?)?.toStringAsFixed(2) ?? '';
    _name = TextEditingController(text: text('name'));
    _description = TextEditingController(text: text('description'));
    _features = TextEditingController(text: ((_plan['features'] as List?) ?? []).join('\n'));
    _appId = TextEditingController(text: text('app_store_product_id'));
    _appPrice = TextEditingController(text: price('app_store_price'));
    _playId = TextEditingController(text: text('play_store_product_id'));
    _playBase = TextEditingController(text: text('play_store_base_plan_id'));
    _playPrice = TextEditingController(text: price('play_store_price'));
    for (final e in (_plan['limits'] as Map<String, dynamic>).entries) {
      _unlimited[e.key] = e.value == null;
      _limits[e.key] = TextEditingController(text: e.value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _features, _appId, _appPrice, _playId, _playBase, _playPrice, ..._limits.values]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The edit as an API payload: changed fields only. Throws a message
  /// string for input the server would reject anyway.
  Map<String, dynamic> _changes() {
    final changes = <String, dynamic>{};
    void text(String key, TextEditingController c) {
      final value = c.text.trim();
      final next = value.isEmpty ? null : value;
      if (next != _plan[key]) changes[key] = next;
    }

    void price(String key, TextEditingController c, String store) {
      final raw = c.text.trim();
      final next = raw.isEmpty ? null : double.tryParse(raw);
      if (raw.isNotEmpty && (next == null || next < 0 || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw))) {
        throw '$store price must be an amount like 9.90';
      }
      if (next != (_plan[key] as num?)?.toDouble()) changes[key] = next == null ? null : raw;
    }

    if (_name.text.trim().isEmpty) throw 'The plan needs a name';
    text('name', _name);
    text('description', _description);
    final features = _features.text.split('\n').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
    if (features.join('\n') != ((_plan['features'] as List?) ?? []).join('\n')) changes['features'] = features;

    final limits = <String, int?>{};
    for (final metric in _limits.keys) {
      if (_unlimited[metric] == true) {
        limits[metric] = null;
      } else {
        final value = int.tryParse(_limits[metric]!.text.trim());
        if (value == null || value < 0) throw '${adminMetricLabel(metric)} must be a whole number, or unlimited';
        limits[metric] = value;
      }
    }
    final oldLimits = _plan['limits'] as Map<String, dynamic>;
    if (limits.entries.any((e) => oldLimits[e.key] != e.value)) changes['limits'] = limits;

    text('app_store_product_id', _appId);
    price('app_store_price', _appPrice, 'App Store');
    text('play_store_product_id', _playId);
    text('play_store_base_plan_id', _playBase);
    price('play_store_price', _playPrice, 'Google Play');
    return changes;
  }

  Future<void> _save() async {
    final Map<String, dynamic> changes;
    try {
      changes = _changes();
    } on String catch (message) {
      setState(() => _error = message);
      return;
    }
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (changes.containsKey('app_store_price') || changes.containsKey('play_store_price')) {
      final ok = await confirmAdminAction(
        context,
        title: 'Change the price?',
        message: 'The new price will be sent to the App Store and Google Play. It applies '
            'to new subscribers; people already subscribed keep their current price.\n\n'
            'Stores can take up to a day to apply a change. The plan shows '
            '"Waiting for stores" until both confirm.',
        confirmLabel: 'Change price',
      );
      if (!ok || !mounted) return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await ApiService.updatePlanAdmin(_plan['key'] as String, changes);
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not save the plan.'; _saving = false; });
    }
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(color: Ui.muted, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      );

  Widget _field(TextEditingController c, String label, {String? helper, int lines = 1, bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
          decoration: adminInputDecoration(label, helper: helper),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final currency = _plan['currency'] == 'MYR' ? 'RM' : _plan['currency'];
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Edit ${_plan['name']} plan'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),
              _section('Shown to users'),
              _field(_name, 'Plan name'),
              _field(_description, 'Short description'),
              _field(_features, 'Features', lines: 5, helper: 'One per line. Shown as a checklist on the plan card.'),
              _section('Limits'),
              for (final metric in _limits.keys)
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _limits[metric],
                      enabled: _unlimited[metric] != true,
                      keyboardType: TextInputType.number,
                      decoration: adminInputDecoration(adminMetricLabel(metric)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: _unlimited[metric],
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setState(() => _unlimited[metric] = v ?? false),
                  ),
                  const Text('Unlimited'),
                ]).withBottomGap(),
              _section('App Store (iPhone)'),
              _field(_appId, 'Product ID', helper: 'As set up in App Store Connect, e.g. pro_monthly.'),
              _field(_appPrice, 'Price ($currency)', number: true,
                  helper: 'Apple only allows its own price steps. If this amount is not one of them, '
                      'the change fails and the closest allowed prices are shown.'),
              _section('Google Play (Android)'),
              _field(_playId, 'Product ID'),
              _field(_playBase, 'Base plan ID', helper: 'The base plan inside the product, e.g. monthly.'),
              _field(_playPrice, 'Price ($currency)', number: true),
              if (_plan['key'] == 'free')
                const Text(
                  'The free plan is not sold in the stores, so leave its store fields empty.',
                  style: TextStyle(fontSize: 12, color: Ui.muted),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

extension on Widget {
  Widget withBottomGap() => Padding(padding: const EdgeInsets.only(bottom: 10), child: this);
}
