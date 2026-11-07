import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/api/api_cache.dart';
import 'package:aidvise_platform/user/widgets/job_card.dart';
import 'package:aidvise_platform/user/widgets/job_details_sheet.dart';
import 'package:aidvise_platform/user/utils/job_apply.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Browse all live vendor job listings with search, occupation filter
/// and infinite-scroll pagination.
class JobBrowseScreen extends StatefulWidget {
  /// Preselects an occupation filter chip (e.g. from the home status chip).
  final int? initialOccupationId;
  const JobBrowseScreen({super.key, this.initialOccupationId});

  @override
  State<JobBrowseScreen> createState() => _JobBrowseScreenState();
}

class _JobBrowseScreenState extends State<JobBrowseScreen> {
  static const _pageSize = 10;

  final TextEditingController _search = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  final List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _filters = [];
  int? _occupationId; // null = every occupation
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;      // first page / new query
  bool _loadingMore = false; // subsequent pages
  String? _error;

  @override
  void initState() {
    super.initState();
    _occupationId = widget.initialOccupationId;
    _scroll.addListener(_onScroll);
    _loadFilters();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _loadFilters() async {
    try {
      // Occupations that actually have live listings, busiest first — not the
      // vendor autocomplete, which with no query returns occupations
      // alphabetically and filtered every chip to an empty page.
      final filters = await ApiService.getJobBrowseFilters();
      if (mounted) setState(() => _filters = filters);
    } catch (_) {
      // Filter chips just won't show; search and browsing still work.
    }
  }

  Future<void> _load({required bool reset, bool refresh = false}) async {
    if (refresh) {
      // Drop every cached browse page so load-more refetches too.
      ApiCache.invalidate('jobs.browse');
    }
    if (reset && !refresh) {
      setState(() { _loading = true; _error = null; _page = 1; });
    } else if (reset) {
      setState(() { _error = null; _page = 1; });
    }
    try {
      final result = await ApiService.browseJobs(
        search: _search.text.trim(),
        occupationId: _occupationId,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _jobs.clear();
        _jobs.addAll((result['jobs'] as List<dynamic>).cast<Map<String, dynamic>>());
        _total = result['total'] as int? ?? _jobs.length;
        _hasMore = result['has_more'] as bool? ?? false;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; _loadingMore = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load jobs. Check your connection.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    setState(() { _loadingMore = true; _page += 1; });
    await _load(reset: false);
  }

  void _selectOccupation(int? id) {
    if (_occupationId == id) return;
    setState(() => _occupationId = id);
    _load(reset: true);
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
        title: const Text('Browse Jobs', style: TextStyle(color: AppTheme.primary)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_filters.isNotEmpty) _buildOccupationChips(),
          const SizedBox(height: 4),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _search,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: AppTheme.primary, fontSize: 14),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search title, company or keywords...',
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF888888)),
          suffixIcon: _search.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF888888)),
                  onPressed: () {
                    _search.clear();
                    _load(reset: true);
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildOccupationChips() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('All', _occupationId == null, () => _selectOccupation(null)),
          ..._filters.map((f) {
            final id = f['id'] as int;
            final title = f['title'] as String? ?? '';
            final count = f['count'] as int? ?? 0;
            return _chip(
              count > 0 ? '$title ($count)' : title,
              _occupationId == id,
              () => _selectOccupation(id),
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFDDDDDD)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF666666),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _load(reset: true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, foregroundColor: Colors.white, elevation: 0),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_jobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('No jobs match your search.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 14)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true, refresh: true),
      color: AppTheme.primary,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _jobs.length + 2, // +1 count header, +1 footer
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '$_total ${_total == 1 ? 'job' : 'jobs'} found',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
            );
          }
          if (index == _jobs.length + 1) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary))),
              );
            }
            if (!_hasMore && _jobs.length > 3) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('You\'ve seen all listings.',
                        style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12))),
              );
            }
            return const SizedBox.shrink();
          }
          final job = _jobs[index - 1];
          return JobCard(
            job: job,
            onTap: () => showJobDetailsSheet(
              context,
              job,
              onApply: () async {
                await applyToJob(context, job);
                if (mounted) _load(reset: true); // pick up the applied flag
              },
            ),
            onApply: () async {
              await applyToJob(context, job);
              if (mounted) _load(reset: true); // pick up the applied flag
            },
          );
        },
      ),
    );
  }
}
