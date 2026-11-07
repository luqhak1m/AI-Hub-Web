import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Shared application-stats dashboard: stat tiles, pipeline breakdown bars,
/// and a trend chart, all filtered by one date-range selector (7D/1M/1Y/All).
/// Used by the vendor workspace (incoming applicants) and the user's
/// My Applications screen — both feeds carry `status` and `applied_at`.
class ApplicationDashboard extends StatefulWidget {
  final List<Map<String, dynamic>> applications;

  const ApplicationDashboard({super.key, required this.applications});

  @override
  State<ApplicationDashboard> createState() => _ApplicationDashboardState();
}

class _ApplicationDashboardState extends State<ApplicationDashboard> {
  _TrendRange _range = _TrendRange.week;

  static const _rangeLabels = {
    _TrendRange.week: '7D',
    _TrendRange.month: '1M',
    _TrendRange.year: '1Y',
    _TrendRange.all: 'All',
  };

  DateTime? get _cutoff {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      _TrendRange.week => today.subtract(const Duration(days: 6)),
      _TrendRange.month => today.subtract(const Duration(days: 27)),
      _TrendRange.year => DateTime(now.year, now.month - 11, 1),
      _TrendRange.all => null,
    };
  }

  /// Applications inside the selected window — tiles, pipeline and trend
  /// all describe the same set.
  List<Map<String, dynamic>> get _windowed {
    final cutoff = _cutoff;
    if (cutoff == null) return widget.applications;
    return widget.applications.where((a) {
      final applied = DateTime.tryParse(a['applied_at'] as String? ?? '')?.toLocal();
      return applied != null && !applied.isBefore(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final windowed = _windowed;
    final counts = {
      'submitted': 0, 'reviewed': 0, 'shortlisted': 0,
      'interview': 0, 'hired': 0, 'rejected': 0,
    };
    for (final a in windowed) {
      final status = a['status'] as String? ?? 'submitted';
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('OVERVIEW',
                  style: TextStyle(
                      color: Color(0xFF888888), fontSize: 11,
                      fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
            ..._rangeLabels.entries.map((entry) {
              final selected = _range == entry.key;
              return GestureDetector(
                onTap: () => setState(() => _range = entry.key),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: selected ? AppTheme.primary : const Color(0xFFDDDDDD)),
                  ),
                  child: Text(entry.value,
                      style: TextStyle(
                        color: selected ? Colors.white : const Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      )),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        _StatTiles(total: windowed.length, counts: counts),
        const SizedBox(height: 14),
        _PipelineChart(counts: counts),
        const SizedBox(height: 14),
        _TrendChart(applications: windowed, range: _range),
      ],
    );
  }
}

class _StatTiles extends StatelessWidget {
  final int total;
  final Map<String, int> counts;
  const _StatTiles({required this.total, required this.counts});

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text('$value',
                    style: const TextStyle(
                        color: AppTheme.primary, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 10,
                        fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile('APPLIED', total),
        tile('REVIEWED', counts['reviewed']!),
        tile('SHORTLISTED', counts['shortlisted']!),
        tile('REJECTED', counts['rejected']!),
      ],
    );
  }
}

/// Horizontal bars: pipeline stage breakdown. Labels carry identity;
/// darker = further along, red reserved for rejected (matches the app's
/// status chips).
class _PipelineChart extends StatelessWidget {
  final Map<String, int> counts;
  const _PipelineChart({required this.counts});

  @override
  Widget build(BuildContext context) {
    // One bar colour for every stage — length carries the comparison, so
    // varying the colour only adds noise.
    const stages = [
      ('Submitted', 'submitted', AppTheme.primary),
      ('Reviewed', 'reviewed', AppTheme.primary),
      ('Shortlisted', 'shortlisted', AppTheme.primary),
      ('Interview', 'interview', AppTheme.primary),
      ('Hired', 'hired', AppTheme.primary),
      ('Rejected', 'rejected', AppTheme.primary),
    ];
    final maxCount = counts.values.fold<int>(1, (m, v) => v > m ? v : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PIPELINE',
              style: TextStyle(
                  color: Color(0xFF888888), fontSize: 11,
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          ...stages.map((stage) {
            final (label, key, color) = stage;
            final value = counts[key]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(label,
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            height: 14,
                            width: value == 0
                                ? 0
                                : constraints.maxWidth * value / maxCount,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text('$value',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

enum _TrendRange { week, month, year, all }

class _TrendBin {
  final String label;
  int count = 0;
  _TrendBin(this.label);
}

/// Column mini-chart: applications over the dashboard's selected range.
/// Binning follows the range so the bars stay readable: 7D = daily,
/// 1M = weekly, 1Y = monthly, All = monthly (yearly beyond 14 months).
class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> applications;
  final _TrendRange range;
  const _TrendChart({required this.applications, required this.range});

  // Chart geometry: value label (14) + gap (3) + tallest bar (12 + 56) +
  // gap (5) + x label (13) = 103 — the box must fit all of it.
  static const double _chartHeight = 106;
  static const double _barMax = 56;
  static const double _barBase = 12;

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  List<DateTime> get _appliedDates => applications
      .map((a) => DateTime.tryParse(a['applied_at'] as String? ?? '')?.toLocal())
      .whereType<DateTime>()
      .toList();

  /// Buckets applications into range-appropriate bins, oldest first.
  List<_TrendBin> _bins() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = _appliedDates;

    switch (range) {
      case _TrendRange.week:
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
        final bins = {for (final d in days) d: _TrendBin(weekdays[d.weekday - 1])};
        for (final date in dates) {
          final key = DateTime(date.year, date.month, date.day);
          bins[key]?.count++;
        }
        return bins.values.toList();

      case _TrendRange.month:
        // Last 28 days as 4 week-bins, labeled by the week's start date
        final bins = <_TrendBin>[];
        final starts = List.generate(4, (i) => today.subtract(Duration(days: 27 - i * 7)));
        for (final start in starts) {
          bins.add(_TrendBin('${start.day}/${start.month}'));
        }
        for (final date in dates) {
          final day = DateTime(date.year, date.month, date.day);
          for (var i = 0; i < starts.length; i++) {
            final end = starts[i].add(const Duration(days: 7));
            if (!day.isBefore(starts[i]) && day.isBefore(end)) {
              bins[i].count++;
              break;
            }
          }
        }
        return bins;

      case _TrendRange.year:
        return _monthlyBins(DateTime(now.year, now.month - 11, 1), 12, dates);

      case _TrendRange.all:
        if (dates.isEmpty) return _monthlyBins(DateTime(now.year, now.month, 1), 1, dates);
        final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
        final monthSpan = (now.year - earliest.year) * 12 + now.month - earliest.month + 1;
        if (monthSpan <= 14) {
          return _monthlyBins(DateTime(earliest.year, earliest.month, 1), monthSpan, dates);
        }
        // Long spans: yearly bins
        final bins = <_TrendBin>[];
        for (var year = earliest.year; year <= now.year; year++) {
          final bin = _TrendBin('$year');
          bin.count = dates.where((d) => d.year == year).length;
          bins.add(bin);
        }
        return bins;
    }
  }

  List<_TrendBin> _monthlyBins(DateTime first, int months, List<DateTime> dates) {
    final bins = <_TrendBin>[];
    for (var i = 0; i < months; i++) {
      final month = DateTime(first.year, first.month + i, 1);
      final bin = _TrendBin(_monthNames[month.month - 1]);
      bin.count = dates
          .where((d) => d.year == month.year && d.month == month.month)
          .length;
      bins.add(bin);
    }
    return bins;
  }

  @override
  Widget build(BuildContext context) {
    final bins = _bins();
    final maxCount = bins.fold<int>(1, (m, b) => b.count > m ? b.count : m);
    // With many bars, value labels collide — only label the peak bins then.
    final labelAll = bins.length <= 8;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('APPLICATIONS',
              style: TextStyle(
                  color: Color(0xFF888888), fontSize: 11,
                  fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bins.map((bin) {
                final value = bin.count;
                final barHeight =
                    value == 0 ? 3.0 : _barBase + _barMax * value / maxCount;
                final showValue = value > 0 && (labelAll || value == maxCount);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showValue)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('$value',
                              style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        height: barHeight,
                        margin: EdgeInsets.symmetric(
                            horizontal: bins.length > 8 ? 2 : 5),
                        decoration: BoxDecoration(
                          color: value == 0 ? const Color(0xFFDDDDDD) : AppTheme.primary,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(bin.label,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: TextStyle(
                              color: const Color(0xFF999999),
                              fontSize: bins.length > 8 ? 8.5 : 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
