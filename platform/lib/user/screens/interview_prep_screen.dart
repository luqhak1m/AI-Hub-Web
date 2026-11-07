import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/user/screens/employer_chat_screen.dart';
import 'package:aidvise_platform/shared/utils/app_page_route.dart';

/// Candidate view of the vendor's interview prep pack: a swipeable card
/// deck, revealed once the vendor moves the application to interview status.
class InterviewPrepScreen extends StatefulWidget {
  final int applicationId;
  const InterviewPrepScreen({super.key, required this.applicationId});

  @override
  State<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends State<InterviewPrepScreen> {
  final PageController _pageController = PageController();
  Map<String, dynamic>? _prep;
  int _page = 0;
  bool _loading = true;
  String? _error;

  static const _typeIcons = {
    'logistics': Icons.event_note_outlined,
    'question': Icons.help_outline,
    'tip': Icons.lightbulb_outline,
    'link': Icons.link,
  };

  static const _typeLabels = {
    'logistics': 'LOGISTICS',
    'question': 'PREPARE FOR THIS QUESTION',
    'tip': 'TIP',
    'link': 'RESOURCE',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prep = await ApiService.getInterviewPrep(widget.applicationId);
      if (!mounted) return;
      setState(() { _prep = prep; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load the prep materials.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _cards =>
      (_prep?['cards'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

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
        title: const Text('Interview Prep', style: TextStyle(color: AppTheme.primary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _prep == null
              ? Center(
                  child: Text(_error ?? 'No prep materials available.',
                      style: const TextStyle(color: Color(0xFF888888))))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        children: [
                          Text(
                            '${_prep!['job_title']} — ${_prep!['company']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.primary, fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Materials from the company to help you prepare. '
                            'Swipe through each card.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF888888), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _cards.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => _buildCard(_cards[i]),
                      ),
                    ),
                    // Page dots
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28, top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_cards.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active ? AppTheme.primary : const Color(0xFFCCCCCC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
    );
  }

  static String _formatEventAt(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} '
        '${dt.year} · $hour:$minute $period';
  }

  Future<void> _openInMaps(Map<String, dynamic> card) async {
    final lat = card['lat'] as num?;
    final lng = card['lng'] as num?;
    final location = card['location'] as String? ?? '';
    final query = (lat != null && lng != null)
        ? '$lat,$lng'
        : Uri.encodeComponent(location);
    try {
      await launchUrl(Uri.parse('https://maps.apple.com/?q=$query'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps.')),
        );
      }
    }
  }

  Future<void> _requestTimeChange() async {
    final note = TextEditingController();
    DateTime? proposed;

    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Request a different time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: note,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Tell them why, e.g. "I have an exam that morning"',
                  hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  counterText: '',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(
                  proposed == null
                      ? 'Suggest a time (optional)'
                      : _formatEventAt(proposed!),
                  style: const TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: dialogContext,
                    initialDate: now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 90)),
                  );
                  if (date == null || !dialogContext.mounted) return;
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: const TimeOfDay(hour: 10, minute: 0),
                  );
                  if (time == null) return;
                  setDialogState(() => proposed = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
            ),
            ElevatedButton(
              onPressed: () {
                if (note.text.trim().length < 3) return;
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  elevation: 0),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );

    if (sent != true) return;
    try {
      await ApiService.requestReschedule(
        widget.applicationId,
        note: note.text.trim(),
        proposedTime: proposed?.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Request sent — the company will get back to you.'),
            backgroundColor: AppTheme.primary),
      );
      _load(); // refresh reschedule state
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the request.')),
        );
      }
    }
  }

  /// Logistics card, in the order the design calls for: label, place, when,
  /// instructions panel, reschedule, map, contact.
  Widget _buildLogisticsCard({
    required Map<String, dynamic> card,
    required String? location,
    required num? lat,
    required num? lng,
    required DateTime? eventAt,
    required bool allowReschedule,
    required bool hasRequest,
  }) {
    final body = (card['body'] as String? ?? '').trim();
    final company = _prep?['company'] as String? ?? 'the employer';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardGrey,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: AppTheme.cardHairline, width: 0.8),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icon + LOGISTICS
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: AppTheme.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.directions_bus,
                        size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('LOGISTICS',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1)),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // 2. Location name
              if (location != null && location.isNotEmpty)
                _logisticsLine(Icons.location_on, location),

              // 3. Day, date, time
              if (eventAt != null) ...[
                const SizedBox(height: 8),
                _logisticsLine(Icons.calendar_month, _formatEventAt(eventAt)),
              ],

              // 4. Instructions panel
              if (body.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppTheme.cardHairline, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INSTRUCTIONS',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Text(body,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 14,
                              height: 1.55)),
                    ],
                  ),
                ),
              ],

              // 5. Request a different time
              if (eventAt != null && allowReschedule) ...[
                const SizedBox(height: 18),
                if (hasRequest)
                  const Row(
                    children: [
                      Icon(Icons.schedule_send,
                          size: 15, color: AppTheme.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Time change requested — awaiting reply',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _requestTimeChange,
                      child: const Text('Request a different time',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],

              // 6. Map
              if (lat != null && lng != null) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 170,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter:
                                LatLng(lat.toDouble(), lng.toDouble()),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom |
                                  InteractiveFlag.drag,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.aiHubFrontend',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point:
                                      LatLng(lat.toDouble(), lng.toDouble()),
                                  width: 36,
                                  height: 36,
                                  child: const Icon(Icons.location_pin,
                                      size: 36, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: TextButton(
                            onPressed: () => _openInMaps(card),
                            child: const Text('Open in Maps',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.primary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 7. Contact the employer
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.forum_outlined, size: 17),
                  label: Text('Contact $company',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    AppPageRoute(
                      builder: (_) => EmployerChatScreen(
                        company: company,
                        applicationId: widget.applicationId,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logisticsLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.35)),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> card) {
    final type = card['type'] as String? ?? 'tip';
    final url = card['url'] as String?;
    final location = card['location'] as String?;
    final lat = card['lat'] as num?;
    final lng = card['lng'] as num?;
    final eventAt = DateTime.tryParse(card['event_at'] as String? ?? '')?.toLocal();
    final allowReschedule = card['allow_reschedule'] == true;
    final hasRequest = _prep?['reschedule_request'] != null;

    if (type == 'logistics') {
      return _buildLogisticsCard(
        card: card,
        location: location,
        lat: lat,
        lng: lng,
        eventAt: eventAt,
        allowReschedule: allowReschedule,
        hasRequest: hasRequest,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_typeIcons[type], size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_typeLabels[type] ?? type.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 10.5,
                          fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(card['title'] as String? ?? '',
                style: const TextStyle(
                    color: AppTheme.primary, fontSize: 19,
                    fontWeight: FontWeight.w800, height: 1.3)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card['body'] as String? ?? '',
                        style: const TextStyle(
                            color: Color(0xFF444444), fontSize: 15, height: 1.6)),
                    if (eventAt != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_formatEventAt(eventAt),
                                  style: const TextStyle(
                                      color: AppTheme.primary, fontSize: 13.5,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      if (allowReschedule) ...[
                        const SizedBox(height: 8),
                        hasRequest
                            ? const Row(
                                children: [
                                  Icon(Icons.schedule_send, size: 15,
                                      color: Color(0xFF666666)),
                                  SizedBox(width: 6),
                                  Text('Time change requested — awaiting reply',
                                      style: TextStyle(
                                          color: Color(0xFF666666), fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              )
                            : OutlinedButton.icon(
                                icon: const Icon(Icons.schedule_send, size: 15),
                                label: const Text('Request a different time',
                                    style: TextStyle(fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _requestTimeChange,
                              ),
                      ],
                    ],
                    if (location != null && location.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      if (lat != null && lng != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            height: 150,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter:
                                    LatLng(lat.toDouble(), lng.toDouble()),
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.pinchZoom |
                                      InteractiveFlag.drag,
                                ),
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
                                      point:
                                          LatLng(lat.toDouble(), lng.toDouble()),
                                      width: 36,
                                      height: 36,
                                      child: const Icon(Icons.location_pin,
                                          size: 36, color: AppTheme.primary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: Color(0xFF888888)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(location,
                                style: const TextStyle(
                                    color: Color(0xFF666666), fontSize: 12.5)),
                          ),
                          TextButton(
                            onPressed: () => _openInMaps(card),
                            child: const Text('Open in Maps',
                                style: TextStyle(
                                    color: AppTheme.primary, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (type == 'link' && url != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Resource',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    try {
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open the link.')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
