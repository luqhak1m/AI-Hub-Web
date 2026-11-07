import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/vendor/screens/assessment_builder_screen.dart';
import 'package:aidvise_platform/vendor/screens/prep_builder_screen.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/widgets/app_card.dart';
import 'package:aidvise_platform/shared/widgets/listing_form_sheet.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Vendor listings management: post, edit, pause and delete job listings,
/// and manage each listing's screening assessment.
class VendorListingsScreen extends StatefulWidget {
  const VendorListingsScreen({super.key});

  @override
  State<VendorListingsScreen> createState() => _VendorListingsScreenState();
}

class _VendorListingsScreenState extends State<VendorListingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _applications = []; // for per-listing counts

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final listings = await ApiService.getVendorListings();
      final applications = await ApiService.getVendorApplications();
      setState(() {
        _listings = listings;
        _applications = applications;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load your listings.'; _loading = false; });
    }
  }

  Future<void> _deleteListing(int id) async {
    try {
      await ApiService.deleteVendorListing(id);
      await _load();
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not delete listing.');
    }
  }

  /// Opens the listing form — empty for create, prefilled for edit.
  Future<void> _openListingSheet({Map<String, dynamic>? existing}) async {
    final saved = await showListingFormSheet(
      context,
      existing: existing,
      save: (payload) => existing != null
          ? ApiService.updateVendorListing(existing['id'] as int, payload)
          : ApiService.createVendorListing(payload),
    );
    if (saved) _load();
  }

  Widget _assessmentSection(BuildContext sheetContext, Map<String, dynamic> listing) {
    final listingId = listing['id'] as int;
    final assessment = listing['assessment'] as Map<String, dynamic>?;
    final questionCount = (assessment?['questions'] as List<dynamic>?)?.length ?? 0;

    Future<void> openBuilder() async {
      Navigator.of(sheetContext).pop();
      final saved = await Navigator.of(context).push<bool>(
        AppPageRoute(
          builder: (_) => AssessmentBuilderScreen(
              listingId: listingId, existing: assessment),
        ),
      );
      if (saved == true) _load();
    }

    if (assessment == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shortlisted candidates can be asked to answer your own screening '
            'questions in the app.',
            style: TextStyle(color: Color(0xFF888888), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.quiz_outlined, size: 16),
            label: const Text('Add Assessment'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
            onPressed: openBuilder,
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.quiz_outlined, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assessment['title'] as String? ?? 'Assessment',
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('$questionCount question${questionCount == 1 ? '' : 's'} · sent on shortlist',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: openBuilder,
            child: const Text('Edit',
                style: TextStyle(color: AppTheme.primary, fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(sheetContext).pop();
              try {
                await ApiService.removeListingAssessment(listingId);
                _load();
              } on ApiException catch (e) {
                if (mounted && handleSessionExpiry(context, e)) return;
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF233C), fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _prepSection(BuildContext sheetContext, Map<String, dynamic> listing) {
    final listingId = listing['id'] as int;
    final prep = listing['interview_prep'] as Map<String, dynamic>?;
    final cardCount = (prep?['cards'] as List<dynamic>?)?.length ?? 0;

    Future<void> openBuilder() async {
      Navigator.of(sheetContext).pop();
      final saved = await Navigator.of(context).push<bool>(
        AppPageRoute(
          builder: (_) => PrepBuilderScreen(listingId: listingId, existing: prep),
        ),
      );
      if (saved == true) _load();
    }

    if (prep == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prep cards are revealed to candidates when you set their '
            'application to Interview status.',
            style: TextStyle(color: Color(0xFF888888), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.school_outlined, size: 16),
            label: const Text('Add Prep Cards'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
            onPressed: openBuilder,
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Interview prep pack',
                    style: TextStyle(
                        color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('$cardCount card${cardCount == 1 ? '' : 's'} · sent on interview status',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: openBuilder,
            child: const Text('Edit',
                style: TextStyle(color: AppTheme.primary, fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(sheetContext).pop();
              try {
                await ApiService.removeListingPrep(listingId);
                _load();
              } on ApiException catch (e) {
                if (mounted && handleSessionExpiry(context, e)) return;
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF233C), fontSize: 12.5)),
          ),
        ],
      ),
    );
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
        title: Text('My Listings (${_listings.length})',
            style: const TextStyle(color: AppTheme.primary)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openListingSheet(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Listing'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFEF233C), fontSize: 13)),
                    ),
                  if (_listings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No listings yet. Tap "New Listing" to post your first job.',
                          style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
                    ),
                  ..._listings.map(_buildListingCard),
                  const SizedBox(height: 80), // room for the FAB
                ],
              ),
            ),
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final id = listing['id'] as int;
    final family = listing['occupation_title'] as String? ?? '';
    final location = listing['location'] as String? ?? '';
    final salary = listing['salary'] as String? ?? '';
    final isActive = listing['is_active'] != false;
    final applicantCount =
        _applications.where((a) => a['listing_id'] == id).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        compact: true,
        icon: Icons.work,
        title: listing['title'] as String? ?? '',
        inlineTag: isActive ? null : 'PAUSED',
        description: [
          family,
          if (location.isNotEmpty || salary.isNotEmpty)
            [location, salary].where((s) => s.isNotEmpty).join(' · '),
        ].where((s) => s.isNotEmpty).join('\n'),
        status: applicantCount == 1 ? '1 applicant' : '$applicantCount applicants',
        statusIcon: Icons.people_outline,
        onTap: () => _showListingDetails(listing),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline,
                size: 20, color: Color(0xFFEF233C)),
            tooltip: 'Delete listing',
            onPressed: () => _deleteListing(id),
          ),
        ],
      ),
    );
  }

  void _showListingDetails(Map<String, dynamic> listing) {
    final id = listing['id'] as int;
    final skills = (listing['required_skills'] as List<dynamic>? ?? []).cast<String>();
    final applicantCount =
        _applications.where((a) => a['listing_id'] == id).length;
    final posted = _formatDate(listing['created_at'] as String?);
    var isActive = listing['is_active'] != false;
    var toggling = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget infoRow(IconData icon, String value) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: const Color(0xFF888888)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(value,
                          style: const TextStyle(color: Color(0xFF444444), fontSize: 13)),
                    ),
                  ],
                ),
              );

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 32 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing['title'] as String? ?? '',
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(listing['occupation_title'] as String? ?? '',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const SizedBox(height: 16),
                infoRow(Icons.people_outline,
                    applicantCount == 1 ? '1 applicant' : '$applicantCount applicants'),
                if ((listing['location'] as String? ?? '').isNotEmpty)
                  infoRow(Icons.location_on_outlined, listing['location'] as String),
                if ((listing['salary'] as String? ?? '').isNotEmpty)
                  infoRow(Icons.payments_outlined, listing['salary'] as String),
                infoRow(Icons.work_outline,
                    listing['employment_type'] as String? ?? 'Full-time'),
                if (posted != null) infoRow(Icons.schedule, 'Posted $posted'),
                const SizedBox(height: 12),
                const Text('DESCRIPTION',
                    style: TextStyle(
                        color: Color(0xFF888888), fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(listing['description'] as String? ?? '',
                    style: const TextStyle(
                        color: Color(0xFF444444), fontSize: 13.5, height: 1.5)),
                const SizedBox(height: 16),
                const Text('REQUIRED SKILLS (USED FOR SCORING)',
                    style: TextStyle(
                        color: Color(0xFF888888), fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                if (skills.isEmpty)
                  const Text('None set — the skills score is skipped for this listing.',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skills
                        .map((skill) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppTheme.cardShadow,
                              ),
                              child: Text(skill,
                                  style: const TextStyle(
                                      color: AppTheme.primary, fontSize: 12)),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 16),
                const Text('SCREENING ASSESSMENT',
                    style: TextStyle(
                        color: Color(0xFF888888), fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _assessmentSection(sheetContext, listing),
                const SizedBox(height: 16),
                const Text('INTERVIEW PREP',
                    style: TextStyle(
                        color: Color(0xFF888888), fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _prepSection(sheetContext, listing),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Listing'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _openListingSheet(existing: listing);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isActive ? 'Listing is live' : 'Listing is paused',
                                style: const TextStyle(
                                    color: AppTheme.primary, fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const Text('Paused listings are hidden from job seekers.',
                                style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
                          ],
                        ),
                      ),
                      Switch(
                        value: isActive,
                        activeTrackColor: AppTheme.primary,
                        onChanged: toggling
                            ? null
                            : (value) async {
                                setSheetState(() => toggling = true);
                                try {
                                  await ApiService.setVendorListingActive(id, value);
                                  setSheetState(() {
                                    isActive = value;
                                    toggling = false;
                                  });
                                  _load(); // refresh cards behind the sheet
                                } catch (_) {
                                  setSheetState(() => toggling = false);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String? _formatDate(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

/// Bottom sheet form for posting a new job listing, or editing an existing
/// one when [existing] is provided.
