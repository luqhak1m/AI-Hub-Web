import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Vendor tool: build the interview prep pack attached to a listing —
/// card types: logistics, question, tip, link. Revealed to candidates
/// when the vendor sets their application to interview status.
class PrepBuilderScreen extends StatefulWidget {
  final int listingId;
  final Map<String, dynamic>? existing;
  const PrepBuilderScreen({super.key, required this.listingId, this.existing});

  @override
  State<PrepBuilderScreen> createState() => _PrepBuilderScreenState();
}

class _CardDraft {
  String type;
  final TextEditingController title = TextEditingController();
  final TextEditingController body = TextEditingController();
  final TextEditingController url = TextEditingController();
  // logistics-only
  final TextEditingController location = TextEditingController();
  double? lat;
  double? lng;
  List<Map<String, dynamic>> suggestions = [];
  Timer? suggestDebounce;
  DateTime? eventAt;
  bool allowReschedule = false;

  _CardDraft(this.type, {String? titleText, String? bodyText}) {
    if (titleText != null) title.text = titleText;
    if (bodyText != null) body.text = bodyText;
  }

  void dispose() {
    suggestDebounce?.cancel();
    title.dispose();
    body.dispose();
    url.dispose();
    location.dispose();
  }
}

class _PrepBuilderScreenState extends State<PrepBuilderScreen> {
  final List<_CardDraft> _cards = [];
  bool _saving = false;
  String? _error;

  static const _typeLabels = {
    'logistics': 'Logistics',
    'question': 'Question',
    'tip': 'Tip',
    'link': 'Link',
  };

  static const _typeIcons = {
    'logistics': Icons.event_note_outlined,
    'question': Icons.help_outline,
    'tip': Icons.lightbulb_outline,
    'link': Icons.link,
  };

  // One-tap starters so a vendor can build a pack in two minutes.
  static const _templates = [
    ('logistics', 'Interview format', 'e.g. 30-minute video call with our team lead.'),
    ('question', 'Questions we may ask', 'e.g. Tell us about a project you\'re proud of.'),
    ('tip', 'What to research', 'e.g. Have a look at our recent campaigns and products.'),
    ('tip', 'What to bring', 'e.g. A portfolio or examples of past work, if any.'),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      for (final c in (existing['cards'] as List<dynamic>? ?? [])) {
        final draft = _CardDraft(c['type'] as String);
        draft.title.text = c['title'] as String? ?? '';
        draft.body.text = c['body'] as String? ?? '';
        draft.url.text = c['url'] as String? ?? '';
        draft.location.text = c['location'] as String? ?? '';
        draft.lat = (c['lat'] as num?)?.toDouble();
        draft.lng = (c['lng'] as num?)?.toDouble();
        draft.eventAt = DateTime.tryParse(c['event_at'] as String? ?? '')?.toLocal();
        draft.allowReschedule = c['allow_reschedule'] == true;
        _cards.add(draft);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _cards) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addCard() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Card type',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            ..._typeLabels.entries.map((entry) => ListTile(
                  leading: Icon(_typeIcons[entry.key], size: 20, color: AppTheme.primary),
                  title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (type != null) setState(() => _cards.add(_CardDraft(type)));
  }

  Future<void> _save() async {
    if (_cards.isEmpty) {
      setState(() => _error = 'Add at least one card.');
      return;
    }
    final cards = <Map<String, dynamic>>[];
    for (var i = 0; i < _cards.length; i++) {
      final c = _cards[i];
      final title = c.title.text.trim();
      final body = c.body.text.trim();
      if (title.isEmpty || body.isEmpty) {
        setState(() => _error = 'Card ${i + 1} needs a title and content.');
        return;
      }
      final url = c.url.text.trim();
      if (c.type == 'link' && url.isEmpty) {
        setState(() => _error = 'Card ${i + 1} is a link card — add the URL.');
        return;
      }
      cards.add({
        'id': i + 1,
        'type': c.type,
        'title': title,
        'body': body,
        if (c.type == 'link') 'url': url,
        if (c.type == 'logistics' && c.location.text.trim().isNotEmpty) ...{
          'location': c.location.text.trim(),
          // Coordinates from the place picker; absent means the backend
          // falls back to geocoding the typed text.
          if (c.lat != null) 'lat': c.lat,
          if (c.lng != null) 'lng': c.lng,
        },
        if (c.type == 'logistics' && c.eventAt != null)
          'event_at': c.eventAt!.toUtc().toIso8601String(),
        if (c.type == 'logistics' && c.allowReschedule)
          'allow_reschedule': true,
      });
    }

    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.setListingPrep(widget.listingId, {'cards': cards});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _saving = false; });
    } catch (_) {
      setState(() { _error = 'Could not save. Try again.'; _saving = false; });
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
          icon: const Icon(Icons.close, color: AppTheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Interview Prep', style: TextStyle(color: AppTheme.primary)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                : const Text('Save',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCard,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFEF233C), fontSize: 13)),
            ),
          const Text(
            'These cards are shown to candidates the moment you move their '
            'application to Interview status.',
            style: TextStyle(color: Color(0xFF999999), fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_cards.isEmpty) ...[
            const Text('QUICK START',
                style: TextStyle(
                    color: Color(0xFF888888), fontSize: 11,
                    fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _templates.map((template) {
                final (type, title, hint) = template;
                return GestureDetector(
                  onTap: () => setState(() => _cards.add(
                      _CardDraft(type, titleText: title, bodyText: ''))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCCCCCC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcons[type], size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text('+ $title',
                            style: const TextStyle(color: AppTheme.primary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          ..._cards.asMap().entries.map((e) => _buildCardEditor(e.key, e.value)),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13.5),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  Widget _buildCardEditor(int index, _CardDraft card) {
    // Template hint for the body, matching the card's origin if any
    final template = _templates.where(
        (t) => t.$1 == card.type && t.$2 == card.title.text);
    final bodyHint = template.isNotEmpty ? template.first.$3 : 'Card content';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcons[card.type], size: 15, color: const Color(0xFF888888)),
              const SizedBox(width: 6),
              Text('Card ${index + 1} · ${_typeLabels[card.type]}',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 11.5,
                      fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _cards.removeAt(index).dispose();
                }),
                child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF888888)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: card.title,
            style: const TextStyle(
                color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: _decoration('Card title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: card.body,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(color: AppTheme.primary, fontSize: 13.5),
            decoration: _decoration(bodyHint),
          ),
          if (card.type == 'link') ...[
            const SizedBox(height: 8),
            TextField(
              controller: card.url,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: AppTheme.primary, fontSize: 13.5),
              decoration: _decoration('https://...'),
            ),
          ],
          if (card.type == 'logistics') ...[
            const SizedBox(height: 8),
            TextField(
              controller: card.location,
              style: const TextStyle(color: AppTheme.primary, fontSize: 13.5),
              onChanged: (value) => _onLocationTyped(card, value),
              decoration: _decoration(
                      'Location (optional), e.g. Menara ABC, Kuala Lumpur')
                  .copyWith(
                suffixIcon: card.lat != null
                    ? const Icon(Icons.check_circle,
                        size: 18, color: AppTheme.primary)
                    : null,
              ),
            ),
            // Live suggestions — tap one to use its exact address
            if (card.suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: Column(
                  children: [
                    for (final place in card.suggestions)
                      InkWell(
                        onTap: () => _pickSuggestion(card, place),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 16, color: Color(0xFF666666)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  place['name'] as String? ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 12.5,
                                      height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (card.lat != null && card.lng != null) ...[
              const SizedBox(height: 8),
              // Preview so the vendor sees exactly where the pin lands
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120,
                  child: IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(card.lat!, card.lng!),
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.aiHubFrontend',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(card.lat!, card.lng!),
                              width: 32,
                              height: 32,
                              child: const Icon(Icons.location_pin,
                                  size: 32, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Location pinned. This is what candidates will see.',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 11)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 14),
                    label: Text(
                      card.eventAt == null
                          ? 'Set date & time'
                          : _formatEventAt(card.eventAt!),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: Color(0xFFCCCCCC)),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: () => _pickEventAt(card),
                  ),
                ),
                if (card.eventAt != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear date',
                    onPressed: () => setState(() {
                      card.eventAt = null;
                      card.allowReschedule = false;
                    }),
                  ),
              ],
            ),
            if (card.eventAt != null)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Allow candidate to request a time change',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                    ),
                  ),
                  Switch(
                    value: card.allowReschedule,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (v) => setState(() => card.allowReschedule = v),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  /// Debounced typeahead: while the vendor types, fetch matching places and
  /// show them in a dropdown under the field. Typing always invalidates any
  /// previously picked coordinates until a suggestion is tapped again.
  void _onLocationTyped(_CardDraft card, String value) {
    setState(() {
      card.lat = null;
      card.lng = null;
    });
    card.suggestDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      if (card.suggestions.isNotEmpty) setState(() => card.suggestions = []);
      return;
    }
    card.suggestDebounce = Timer(const Duration(milliseconds: 450), () async {
      List<Map<String, dynamic>> results;
      try {
        results = await ApiService.searchPlaces(query);
      } catch (_) {
        return; // suggestions are best-effort; typing still works without them
      }
      // Drop stale responses if the vendor kept typing meanwhile.
      if (!mounted || card.location.text.trim() != query) return;
      setState(() => card.suggestions = results);
    });
  }

  void _pickSuggestion(_CardDraft card, Map<String, dynamic> place) {
    setState(() {
      card.location.text = place['name'] as String? ?? '';
      card.lat = (place['lat'] as num?)?.toDouble();
      card.lng = (place['lng'] as num?)?.toDouble();
      card.suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  static String _formatEventAt(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
  }

  Future<void> _pickEventAt(_CardDraft card) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: card.eventAt ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: card.eventAt != null
          ? TimeOfDay.fromDateTime(card.eventAt!)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    setState(() => card.eventAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}
