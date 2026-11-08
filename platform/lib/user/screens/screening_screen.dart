import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Candidate side of a vendor screening assessment: fetches the questions
/// for a shortlisted application and submits answers.
class ScreeningScreen extends StatefulWidget {
  final int applicationId;
  const ScreeningScreen({super.key, required this.applicationId});

  @override
  State<ScreeningScreen> createState() => _ScreeningScreenState();
}

class _ScreeningScreenState extends State<ScreeningScreen> {
  Map<String, dynamic>? _assessment;
  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _textControllers = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final assessment = await ApiService.getCandidateAssessment(widget.applicationId);
      if (!mounted) return;
      setState(() { _assessment = assessment; _loading = false; });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Could not load the assessment.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _questions =>
      (_assessment?['questions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  bool get _complete {
    for (final q in _questions) {
      final answer = _answers[q['id'] as int];
      if (answer == null) return false;
      if (q['type'] == 'text' && (answer as String).trim().isEmpty) return false;
    }
    return _questions.isNotEmpty;
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final result = await ApiService.submitCandidateAssessment(
        widget.applicationId,
        _answers.entries
            .map((e) => {'question_id': e.key, 'answer': e.value})
            .toList(),
      );
      if (!mounted) return;
      final score = result['score'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(score != null
              ? 'Assessment submitted — you scored ${(score as num).round()} on the objective questions!'
              : 'Assessment submitted! The company will review your answers.'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _error = e.message; _submitting = false; });
    } catch (_) {
      setState(() { _error = 'Submission failed. Try again.'; _submitting = false; });
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
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_assessment?['title'] as String? ?? 'Assessment',
            style: const TextStyle(color: AppTheme.primary)),
      ),
      bottomNavigationBar: _loading || _assessment == null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Ui.surface,
                border: Border(top: BorderSide(color: Ui.line)),
              ),
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: (_complete && !_submitting) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Ui.surface3,
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _complete
                              ? 'Submit Answers'
                              : 'Answer all ${_questions.length} questions',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _assessment == null
              ? Center(
                  child: Text(_error ?? 'No assessment available.',
                      style: const TextStyle(color: Ui.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Screening questions from ${_assessment!['company'] ?? 'the company'}. '
                      'Answer carefully — you can only submit once.',
                      style: const TextStyle(
                          color: Ui.muted, fontSize: 12.5, height: 1.4),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_error!,
                            style: const TextStyle(color: Ui.bad, fontSize: 13)),
                      ),
                    const SizedBox(height: 14),
                    ..._questions.asMap().entries.map(
                        (e) => _buildQuestion(e.key, e.value)),
                  ],
                ),
    );
  }

  Widget _buildQuestion(int index, Map<String, dynamic> question) {
    final qid = question['id'] as int;
    final type = question['type'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ui.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${question['text']}',
              style: const TextStyle(
                  color: AppTheme.primary, fontSize: 14,
                  fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 10),
          switch (type) {
            'choice' => _choiceInput(qid, question),
            'text' => _textInput(qid),
            'rating' => _ratingInput(qid),
            _ => _sliderInput(qid),
          },
        ],
      ),
    );
  }

  Widget _choiceInput(int qid, Map<String, dynamic> question) {
    final options = (question['options'] as List<dynamic>).cast<String>();
    return Column(
      children: options.asMap().entries.map((entry) {
        final selected = _answers[qid] == entry.key;
        return GestureDetector(
          onTap: () => setState(() => _answers[qid] = entry.key),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: selected ? AppTheme.primary : Ui.line),
            ),
            child: Text(entry.value,
                style: TextStyle(
                    color: selected ? Colors.white : AppTheme.primary,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _textInput(int qid) {
    final controller = _textControllers.putIfAbsent(qid, TextEditingController.new);
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 2,
      maxLength: 2000,
      style: const TextStyle(color: AppTheme.primary, fontSize: 13.5),
      onChanged: (v) => setState(() => _answers[qid] = v),
      decoration: InputDecoration(
        hintText: 'Type your answer...',
        hintStyle: const TextStyle(color: Ui.muted, fontSize: 13.5),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _ratingInput(int qid) {
    final current = _answers[qid] as int? ?? 0;
    return Row(
      children: List.generate(5, (i) {
        final filled = i < current;
        return GestureDetector(
          onTap: () => setState(() => _answers[qid] = i + 1),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: 32,
              color: filled ? AppTheme.primary : Ui.muted,
            ),
          ),
        );
      }),
    );
  }

  Widget _sliderInput(int qid) {
    final value = (_answers[qid] as num?)?.toDouble();
    return Column(
      children: [
        Slider(
          value: value ?? 50,
          min: 0,
          max: 100,
          divisions: 100,
          activeColor: AppTheme.primary,
          inactiveColor: Ui.line,
          label: '${(value ?? 50).round()}',
          onChanged: (v) => setState(() => _answers[qid] = v.round()),
        ),
        Text(
          value == null ? 'Slide to answer' : '${value.round()} / 100',
          style: TextStyle(
              color: value == null ? Ui.muted : AppTheme.primary,
              fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
