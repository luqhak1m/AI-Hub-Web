import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/admin/admin_page.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/shared/widgets/listing_form_sheet.dart';

/// Every vendor's job listings: fix a listing's details, or hide one from
/// job seekers (and show it again).
class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen>
    with AdminPagedList<AdminListingsScreen> {
  String? _query;
  bool? _active;

  @override
  Future<Map<String, dynamic>> fetchPage(int skip, int limit) =>
      ApiService.getAdminListings(query: _query, isActive: _active, skip: skip, limit: limit);

  @override
  String get loadError => 'Could not load job listings.';

  Future<void> _edit(Map<String, dynamic> listing) async {
    Map<String, dynamic>? updated;
    final saved = await showListingFormSheet(
      context,
      existing: listing,
      save: (payload) async =>
          updated = await ApiService.updateListingAdmin(listing['id'] as int, payload),
    );
    if (saved && updated != null && mounted) {
      replaceItem(updated!);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing saved'), backgroundColor: AppTheme.primary));
    }
  }

  Future<void> _toggle(Map<String, dynamic> listing) async {
    final active = listing['is_active'] == true;
    final ok = await confirmAdminAction(
      context,
      title: active ? 'Hide this listing?' : 'Show this listing?',
      message: active
          ? 'Job seekers will no longer see "${listing['title']}" or be able to apply. '
              'Existing applications are kept. You can show it again at any time.'
          : 'Job seekers will be able to see "${listing['title']}" and apply again.',
      confirmLabel: active ? 'Hide' : 'Show',
      danger: active,
    );
    if (!ok || !mounted) return;
    final updated = await runAdminAction(
        context, () => ApiService.setListingActiveAdmin(listing['id'] as int, !active),
        success: active ? 'Listing hidden' : 'Listing shown');
    if (updated != null) replaceItem(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      title: 'Job Listings',
      searchHint: 'Search by job title or company',
      onSearch: (q) { _query = q.trim(); load(); },
      filters: AdminFilterChips<bool>(
        options: const [(null, 'All'), (true, 'Shown'), (false, 'Hidden')],
        selected: _active,
        onSelected: (v) { _active = v; load(); },
      ),
      body: AdminListState(
        loading: loading,
        error: error,
        empty: items.isEmpty,
        emptyText: 'No listings match.',
        onRetry: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: pagedChildren('listing', [
            for (final l in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  compact: true,
                  icon: Icons.work_outline,
                  title: l['title'] as String,
                  inlineTag: l['is_active'] == true ? null : 'HIDDEN',
                  description: [
                    l['company_name'] ?? 'Unknown employer',
                    if (l['location'] != null) l['location'],
                    if (l['salary'] != null) l['salary'],
                  ].join(' · '),
                  onTap: () => _edit(l),
                  actions: [
                    TextButton(onPressed: () => _edit(l), child: const Text('Edit')),
                    TextButton(
                      onPressed: () => _toggle(l),
                      style: TextButton.styleFrom(
                          foregroundColor: l['is_active'] == true ? AppTheme.danger : AppTheme.primary),
                      child: Text(l['is_active'] == true ? 'Hide' : 'Show'),
                    ),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
