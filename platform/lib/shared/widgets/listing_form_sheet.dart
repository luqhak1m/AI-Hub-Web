import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Opens the listing form as a bottom sheet — empty for create, prefilled
/// for edit. Returns true when the listing was saved.
Future<bool> showListingFormSheet(
  BuildContext context, {
  Map<String, dynamic>? existing,
  required Future<void> Function(Map<String, dynamic> payload) save,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ListingFormSheet(existing: existing, save: save),
  );
  return saved == true;
}

/// The job listing form. The caller decides where it saves — the admin
/// panel to any listing; the employer area, later, to the vendor's own.
class ListingFormSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;

  /// Persists the form.
  final Future<void> Function(Map<String, dynamic> payload) save;

  const ListingFormSheet({super.key, this.existing, required this.save});

  @override
  State<ListingFormSheet> createState() => _ListingFormSheetState();
}

class _ListingFormSheetState extends State<ListingFormSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _salary = TextEditingController();
  final _skills = TextEditingController();

  int? _occupationId;
  String? _occupationTitle;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing['title'] as String? ?? '';
      _description.text = existing['description'] as String? ?? '';
      _location.text = existing['location'] as String? ?? '';
      _salary.text = existing['salary'] as String? ?? '';
      _skills.text =
          ((existing['required_skills'] as List<dynamic>?) ?? []).join(', ');
      _occupationId = existing['occupation_id'] as int?;
      _occupationTitle = existing['occupation_title'] as String?;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _salary.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 3 ||
        _description.text.trim().length < 10 ||
        _occupationId == null) {
      setState(() => _error =
          'Title, description (10+ characters) and occupation are required.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final skills = _skills.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final payload = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'occupation_id': _occupationId,
        if (_location.text.trim().isNotEmpty) 'location': _location.text.trim(),
        if (_salary.text.trim().isNotEmpty) 'salary': _salary.text.trim(),
        'required_skills': skills,
      };
      await widget.save(payload);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _submitting = false; });
    } catch (_) {
      setState(() { _error = 'Failed to post listing.'; _submitting = false; });
    }
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Ui.muted, fontSize: 14),
        filled: true,
        fillColor: Ui.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing != null ? 'Edit Job Listing' : 'New Job Listing',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: Ui.bad, fontSize: 13)),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _title,
              style: const TextStyle(color: AppTheme.primary, fontSize: 14),
              decoration: _decoration('Job title, e.g. Digital Marketing Executive'),
            ),
            const SizedBox(height: 10),
            // Search-and-confirm rather than a dropdown: there are ~900
            // occupations, and matching a job title to one automatically is
            // unreliable enough to be worse than asking. The vendor knows
            // what their own role is; we only shorten the list.
            Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(text: _occupationTitle ?? ''),
              displayStringForOption: (option) =>
                  option['title'] as String? ?? '',
              optionsBuilder: (value) async {
                final query = value.text.trim();
                if (query.length < 2) return const <Map<String, dynamic>>[];
                try {
                  return await ApiService.searchOccupations(query);
                } catch (_) {
                  return const <Map<String, dynamic>>[];
                }
              },
              onSelected: (option) => setState(() {
                _occupationId = option['id'] as int?;
                _occupationTitle = option['title'] as String?;
              }),
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: AppTheme.primary, fontSize: 14),
                decoration: _decoration('Occupation — type to search'),
                onChanged: (_) {
                  // Typing after a selection invalidates it: the stored id must
                  // never disagree with the text the vendor can see.
                  if (_occupationId != null) {
                    setState(() {
                      _occupationId = null;
                      _occupationTitle = null;
                    });
                  }
                },
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final option in options)
                          ListTile(
                            dense: true,
                            title: Text(option['title'] as String? ?? '',
                                style: const TextStyle(fontSize: 13)),
                            // O*NET's formal name is often not what anyone
                            // calls the job, so when the match came from an
                            // alias, show it — otherwise "Software Developers"
                            // looks like a non-answer to "Software Engineer".
                            subtitle: Text(
                              option['matched_title'] != null
                                  ? 'matches "${option['matched_title']}"'
                                  : option['soc_code'] as String? ?? '',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () => onSelected(option),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              style: const TextStyle(color: AppTheme.primary, fontSize: 14),
              maxLines: 4,
              decoration: _decoration('Role description and requirements'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _skills,
              style: const TextStyle(color: AppTheme.primary, fontSize: 14),
              decoration: _decoration(
                  'Required skills, comma-separated — used to score applicants'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              style: const TextStyle(color: AppTheme.primary, fontSize: 14),
              decoration: _decoration('Location (optional), e.g. Kuala Lumpur'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _salary,
              style: const TextStyle(color: AppTheme.primary, fontSize: 14),
              decoration: _decoration('Salary range (optional), e.g. RM 4,000 – RM 6,000'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  disabledBackgroundColor: Ui.surface3,
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Text(widget.existing != null ? 'Save Changes' : 'Post Listing',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
