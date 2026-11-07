import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';
import 'package:aidvise_platform/shared/utils/session.dart';

/// Layout shared by the admin panel sections: a title bar with optional
/// actions, a search box, filter chips, and a centred column that stays
/// readable on a wide monitor.
class AdminPage extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final String? searchHint;
  final ValueChanged<String>? onSearch;
  final Widget? filters;
  final Widget body;

  const AdminPage({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.searchHint,
    this.onSearch,
    this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onSearch != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    onSubmitted: onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: adminInputDecoration(searchHint ?? 'Search')
                        .copyWith(prefixIcon: const Icon(Icons.search, color: AppTheme.primary)),
                  ),
                ),
              if (filters != null)
                Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: filters),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field styling used across admin forms.
InputDecoration adminInputDecoration(String label, {String? helper}) => InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

/// A row of single-choice filter chips: (value, label) pairs; null value = "All".
class AdminFilterChips<T> extends StatelessWidget {
  final List<(T?, String)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  const AdminFilterChips(
      {super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            selectedColor: AppTheme.primary,
            labelStyle: TextStyle(color: selected == value ? Colors.white : AppTheme.primary),
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

/// Ask before anything that changes what users see or can do. Returns true
/// only on an explicit confirm.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.primary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? AppTheme.danger : AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Runs an admin call and reports the outcome in a snackbar. Returns the
/// call's result, or null when it failed (already reported).
Future<T?> runAdminAction<T>(BuildContext context, Future<T> Function() action,
    {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success), backgroundColor: AppTheme.primary));
    }
    return result;
  } on ApiException catch (e) {
    if (context.mounted && handleSessionExpiry(context, e)) return null;
    messenger.showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Something went wrong. Try again.'), backgroundColor: AppTheme.danger));
  }
  return null;
}

/// Loading / error / empty states for an admin list.
class AdminListState extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool empty;
  final String emptyText;
  final VoidCallback onRetry;
  final Widget child;

  const AdminListState({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.emptyText,
    required this.onRetry,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, style: const TextStyle(color: Color(0xFF888888))),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ]),
      );
    }
    if (empty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Color(0xFF888888))));
    }
    return child;
  }
}

/// Human names for quota metrics (the backend's METRICS keys).
String adminMetricLabel(String metric) => const {
      'chat_messages_per_day': 'Advisor chats per day',
      'resume_generations_per_month': 'Resume generations per month',
    }[metric] ??
    metric.replaceAll('_', ' ');

/// Paged list state for admin sections backed by a {items, total} endpoint.
/// The screen supplies [fetchPage]; the mixin handles first load, "load
/// more", errors and in-place replacement of an edited row.
mixin AdminPagedList<T extends StatefulWidget> on State<T> {
  final List<Map<String, dynamic>> items = [];
  int total = 0;
  bool loading = true;
  bool loadingMore = false;
  String? error;

  static const pageSize = 50;

  Future<Map<String, dynamic>> fetchPage(int skip, int limit);
  String get loadError;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    setState(() {
      if (more) {
        loadingMore = true;
      } else {
        loading = true;
        error = null;
      }
    });
    try {
      final page = await fetchPage(more ? items.length : 0, pageSize);
      if (!mounted) return;
      setState(() {
        if (!more) items.clear();
        items.addAll((page['items'] as List).cast<Map<String, dynamic>>());
        total = page['total'] as int;
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = loadError);
    } finally {
      if (mounted) setState(() { loading = false; loadingMore = false; });
    }
  }

  void replaceItem(Map<String, dynamic> updated) {
    final i = items.indexWhere((x) => x['id'] == updated['id']);
    if (i >= 0) setState(() => items[i] = {...items[i], ...updated});
  }

  /// Count line above the list and "Load more" below it.
  List<Widget> pagedChildren(String noun, Iterable<Widget> rows) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('$total $noun${total == 1 ? '' : 's'}',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ),
        ...rows,
        if (items.length < total)
          Center(
            child: loadingMore
                ? const CircularProgressIndicator(color: AppTheme.primary)
                : TextButton(onPressed: () => load(more: true), child: const Text('Load more')),
          ),
      ];
}
