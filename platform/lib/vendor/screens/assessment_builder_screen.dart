import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Vendor tool: build the screening assessment attached to a listing.
/// Question types: choice (optionally auto-scored), text, rating, slider.
class AssessmentBuilderScreen extends StatefulWidget {
  final int listingId;
  final Map<String, dynamic>? existing;
  const AssessmentBuilderScreen({super.key, required this.listingId, this.existing});

  @override
  State<AssessmentBuilderScreen> createState() => _AssessmentBuilderScreenState();
}

class _QuestionDraft {
  String type;
  final TextEditingController text = TextEditingController();
  final List<TextEditingController> options = [];
  int? correctIndex;

  _QuestionDraft(this.type) {
    if (type == 'choice') {
      options.add(TextEditingController());
      options.add(TextEditingController());
    }
  }

  void dispose() {
    text.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class _AssessmentBuilderScreenState extends State<AssessmentBuilderScreen> {
  final _title = TextEditingController();
  final List<_QuestionDraft> _questions = [];
  bool _saving = false;
  String? _error;

  static const _typeLabels = {
    'choice': 'Multiple Choice',
    'text': 'Written Answer',
    'rating': 'Rating (1–5)',
    'slider': 'Slider (0–100)',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _title.text = existing['title'] as String? ?? '';
      for (final q in (existing['questions'] as List<dynamic>? ?? [])) {
        final draft = _QuestionDraft(q['type'] as String);
        draft.text.text = q['text'] as String? ?? '';
        if (draft.type == 'choice') {
          draft.options.clear();
          for (final opt in (q['options'] as List<dynamic>? ?? [])) {
            draft.options.add(TextEditingController(text: opt as String));
          }
          draft.correctIndex = q['correct_index'] as int?;
        }
        _questions.add(draft);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  Future<void> _addQuestion() async {
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
              child: Text('Question type',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            ..._typeLabels.entries.map((entry) => ListTile(
                  title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                  leading: Icon(switch (entry.key) {
                    'choice' => Icons.radio_button_checked,
                    'text' => Icons.notes,
                    'rating' => Icons.star_outline,
                    _ => Icons.tune,
                  }, size: 20, color: AppTheme.primary),
                  onTap: () => Navigator.of(sheetContext).pop(entry.key),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (type != null) setState(() => _questions.add(_QuestionDraft(type)));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Give the assessment a title.');
      return;
    }
    if (_questions.isEmpty) {
      setState(() => _error = 'Add at least one question.');
      return;
    }
    final questions = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final text = q.text.text.trim();
      if (text.length < 3) {
        setState(() => _error = 'Question ${i + 1} needs text.');
        return;
      }
      final item = <String, dynamic>{'id': i + 1, 'type': q.type, 'text': text};
      if (q.type == 'choice') {
        final options =
            q.options.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
        if (options.length < 2) {
          setState(() => _error = 'Question ${i + 1} needs at least 2 options.');
          return;
        }
        item['options'] = options;
        if (q.correctIndex != null && q.correctIndex! < options.length) {
          item['correct_index'] = q.correctIndex;
        }
      }
      questions.add(item);
    }

    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.setListingAssessment(
          widget.listingId, {'title': title, 'questions': questions});
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
        title: const Text('Screening Assessment', style: TextStyle(color: AppTheme.primary)),
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
        onPressed: _addQuestion,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
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
          TextField(
            controller: _title,
            style: const TextStyle(color: AppTheme.primary, fontSize: 14),
            decoration: _decoration('Assessment title, e.g. Marketing Basics'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sent automatically to candidates you shortlist. Multiple-choice '
            'questions with a marked correct answer are auto-scored.',
            style: TextStyle(color: Color(0xFF999999), fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key, e.value)),
          if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text('No questions yet. Tap "Add Question".',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  Widget _buildQuestionCard(int index, _QuestionDraft q) {
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
              Text('Q${index + 1} · ${_typeLabels[q.type]}',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 11.5,
                      fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _questions.removeAt(index).dispose();
                }),
                child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF888888)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: q.text,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(color: AppTheme.primary, fontSize: 14),
            decoration: _decoration('Question text').copyWith(fillColor: Colors.white),
          ),
          if (q.type == 'choice') ...[
            const SizedBox(height: 10),
            ...q.options.asMap().entries.map((entry) {
              final optionIndex = entry.key;
              final isCorrect = q.correctIndex == optionIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    // Tap to mark this option as the correct answer
                    GestureDetector(
                      onTap: () => setState(() =>
                          q.correctIndex = isCorrect ? null : optionIndex),
                      child: Icon(
                        isCorrect ? Icons.check_circle : Icons.circle_outlined,
                        size: 20,
                        color: isCorrect ? AppTheme.primary : const Color(0xFFBBBBBB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        style: const TextStyle(color: AppTheme.primary, fontSize: 13.5),
                        decoration: _decoration('Option ${optionIndex + 1}')
                            .copyWith(fillColor: Colors.white, isDense: true),
                      ),
                    ),
                    if (q.options.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          q.options.removeAt(optionIndex).dispose();
                          if (q.correctIndex == optionIndex) q.correctIndex = null;
                          if (q.correctIndex != null && q.correctIndex! > optionIndex) {
                            q.correctIndex = q.correctIndex! - 1;
                          }
                        }),
                      ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                if (q.options.length < 6)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 15, color: AppTheme.primary),
                    label: const Text('Add option',
                        style: TextStyle(color: AppTheme.primary, fontSize: 12.5)),
                    onPressed: () =>
                        setState(() => q.options.add(TextEditingController())),
                  ),
                const Spacer(),
                Text(
                  q.correctIndex == null
                      ? 'Tap a circle to mark the correct answer'
                      : 'Auto-scored',
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
