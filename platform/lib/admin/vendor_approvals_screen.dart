import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Admin review queue for employers applying to post job listings.
class AdminManageScreen extends StatefulWidget {
  const AdminManageScreen({super.key});

  @override
  State<AdminManageScreen> createState() => _AdminManageScreenState();
}

class _AdminManageScreenState extends State<AdminManageScreen> {
  List<Map<String, dynamic>> _pendingVendors = [];
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
      final vendors = await ApiService.getPendingVendorsAdmin();
      setState(() { _pendingVendors = vendors; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load vendor applications.'; _loading = false; });
    }
  }

  Future<void> _setVendorStatus(int userId, String status) async {
    try {
      await ApiService.setVendorStatusAdmin(userId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vendor $status')),
        );
      }
      _load();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // No back arrow when shown as a section of the admin panel.
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Approve Vendors', style: TextStyle(color: AppTheme.primary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF888888))))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('PENDING VENDOR APPLICATIONS',
                            style: TextStyle(
                                color: Color(0xFF888888), fontSize: 11,
                                fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                      ),
                      if (_pendingVendors.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                              child: Text('No pending applications.',
                                  style: TextStyle(color: Color(0xFF888888)))),
                        ),
                      ..._pendingVendors.map(_buildVendorCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> v) {
    final userId = v['user_id'] as int;
    final company = v['company_name'] as String? ?? '';
    final applicant = v['full_name'] as String? ?? v['username'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(company,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text('Applicant: $applicant',
              style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  onPressed: () => _setVendorStatus(userId, 'approved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  onPressed: () => _setVendorStatus(userId, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF233C),
                    side: const BorderSide(color: Color(0xFFEF233C)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
