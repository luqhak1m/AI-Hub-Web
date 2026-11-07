import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';

/// Plan management: compare Free vs Pro, upgrade, or cancel.
///
/// The web has no app store, so upgrading activates Pro directly — the same
/// demo path the mobile app takes when no store is available. Real web
/// payments (e.g. Stripe) replace this before launch.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _isPro => (_me?['tier'] as String?) == 'pro';


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([ApiService.getMe(), ApiService.getPlans()]);
      setState(() {
        _me = results[0] as Map<String, dynamic>;
        _plans = (results[1] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your plan.'; _loading = false; });
    }
  }

  Future<void> _upgrade() async {
    setState(() { _working = true; _error = null; });
    try {
      await ApiService.activateProSubscription();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Pro! Your limits have been raised.'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Upgrade failed. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cancel Pro?'),
        content: const Text(
          'You\'ll go back to the Free plan limits immediately. '
          'Your data, resumes and applications are unaffected.\n\n'
          'If you subscribed in the AidVise mobile app, stop the renewal in '
          'your App Store or Google Play subscription settings.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Pro', style: TextStyle(color: AppTheme.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF233C), foregroundColor: Colors.white),
            child: const Text('Cancel Pro'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _working = true; _error = null; });
    try {
      await ApiService.cancelProSubscription();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription cancelled.'),
              backgroundColor: AppTheme.primary),
        );
      }
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Cancellation failed. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

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
        title: const Text('Subscription', style: TextStyle(color: AppTheme.primary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFEF233C), fontSize: 13)),
                  ),
                for (final plan in _plans) ...[
                  _planCard(
                    name: plan['name'] as String,
                    price: _priceLabel(plan),
                    current: (_me?['tier'] as String?) == plan['key'],
                    highlighted: plan['key'] != 'free',
                    features: ((plan['features'] as List?) ?? []).cast<String>(),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  height: 50,
                  child: _isPro
                      ? OutlinedButton(
                          onPressed: _working ? null : _cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF233C),
                            side: const BorderSide(color: Color(0xFFEF233C)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _working
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Color(0xFFEF233C)))
                              : const Text('Cancel Subscription',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        )
                      : ElevatedButton(
                          onPressed: _working ? null : _upgrade,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            disabledBackgroundColor: const Color(0xFFCCCCCC),
                          ),
                          child: _working
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Text('Upgrade to Pro',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isPro
                      ? 'Cancelling returns you to Free limits immediately.'
                      : 'Billed monthly. Cancel anytime.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
                ),
              ],
            ),
    );
  }

  /// "RM 9.90 / month" from the plan's price; plans sold in no store are
  /// free. The web shows the App Store price until it has its own.
  String _priceLabel(Map<String, dynamic> plan) {
    final price = (plan['app_store_price'] ?? plan['play_store_price']) as num?;
    final currency = plan['currency'] == 'MYR' ? 'RM' : plan['currency'] as String? ?? 'RM';
    if (price == null) return '$currency 0';
    return '$currency ${price.toStringAsFixed(2)} / month';
  }

  Widget _planCard({
    required String name,
    required String price,
    required List<String> features,
    required bool current,
    bool highlighted = false,
  }) {
    return AppCard(
      shell: highlighted ? CardShell.emphasis : CardShell.standard,
      icon: Icons.workspace_premium,
      title: name,
      inlineTag: current ? 'CURRENT PLAN' : null,
      titleMeta: price,
      details: [for (final f in features) CardDetail(Icons.check, f)],
    );
  }
}
