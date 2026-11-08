import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/ui/tokens.dart';
import 'package:aidvise_platform/shared/utils/shell_scope.dart';
import 'package:aidvise_platform/shared/api/api_service.dart';
import 'package:aidvise_platform/shared/utils/session.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

class AssessmentScreen extends StatefulWidget {
  /// When true, skips the existing-result check so the user can answer the
  /// questions again (set by the Retake button on the result screen).
  final bool retake;

  const AssessmentScreen({super.key, this.retake = false});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  List<Map<String, dynamic>> _questions = [];
  bool _loadingQuestions = true;
  bool _submitting = false;
  String? _errorMessage;
  int _currentIndex = 0; // 0..length-1 = questions, length = summary

  final Map<int, int?> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Users who already completed the assessment go straight to their latest
  /// result; only first-timers (or retakers) see the questions.
  Future<void> _start() async {
    if (widget.retake) {
      await _loadQuestions();
      return;
    }
    try {
      final existing = await ApiService.getLatestAssessmentResult();
      if (!mounted) return;
      if (existing != null) {
        // Already taken: the Assessment page shows the result.
        Navigator.of(context).pop();
        return;
      }
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      // Fall through to the questions — the check is a convenience, not a gate.
    } catch (_) {}
    await _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() { _loadingQuestions = true; _errorMessage = null; });
    try {
      final questions = await ApiService.getQuestions();
      setState(() {
        _questions = questions;
        _loadingQuestions = false;
        for (final q in questions) {
          _selectedOptions[q['id'] as int] = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() { _errorMessage = e.message; _loadingQuestions = false; });
    } catch (_) {
      setState(() { _errorMessage = 'Could not load questions. Check your connection.'; _loadingQuestions = false; });
    }
  }

  bool get _onSummary => _currentIndex == _questions.length;
  int get _answeredCount => _questions.where((q) => _selectedOptions[q['id'] as int] != null).length;

  void _goTo(int index) => setState(() => _currentIndex = index.clamp(0, _questions.length));

  Future<void> _submit() async {
    setState(() { _submitting = true; _errorMessage = null; });
    try {
      final answers = _questions.map((q) {
        final id = q['id'] as int;
        return {'question_id': id, 'selected_option_id': _selectedOptions[id]};
      }).toList();
      final result = await ApiService.submitAssessment(answers);
      if (!mounted) return;
      // Back to the Assessment page, which reloads and shows the new result.
      Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      if (mounted && handleSessionExpiry(context, e)) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Submission failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showJumpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jump to question',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.primary)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _questions.length,
              itemBuilder: (_, i) {
                final qId = _questions[i]['id'] as int;
                final answered = _selectedOptions[qId] != null;
                final isCurrent = i == _currentIndex;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _goTo(i);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primary
                          : answered
                              ? Ui.muted
                              : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent || answered ? AppTheme.primary : Ui.line,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isCurrent || answered ? Colors.white : Ui.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 6),
                const Text('Current', style: TextStyle(fontSize: 12, color: Ui.muted)),
                const SizedBox(width: 16),
                Container(width: 14, height: 14,
                  decoration: BoxDecoration(color: Ui.muted, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 6),
                const Text('Answered', style: TextStyle(fontSize: 12, color: Ui.muted)),
                const SizedBox(width: 16),
                Container(width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Ui.line),
                  )),
                const SizedBox(width: 6),
                const Text('Unanswered', style: TextStyle(fontSize: 12, color: Ui.muted)),
              ],
            ),
          ],
        ),
      ),
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
        leading: sectionLeading(context),
        title: Text(
          _onSummary ? 'Review Answers' : 'Career Assessment',
          style: const TextStyle(color: AppTheme.primary),
        ),
      ),
      bottomNavigationBar: _loadingQuestions || _questions.isEmpty
          ? null
          : _buildNavBar(context),
      body: _loadingQuestions
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _questions.isEmpty
              ? _buildErrorState()
              : _onSummary
                  ? _buildSummaryPage()
                  : _buildQuestionPage(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Ui.bad, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Ui.muted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadQuestions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage() {
    final q = _questions[_currentIndex];
    final id = q['id'] as int;
    final text = q['text'] as String;
    final options = (q['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final total = _questions.length;
    final answered = _answeredCount;
    final progress = total > 0 ? answered / total : 0.0;

    return Column(
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Ui.line, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$answered of $total answered',
                      style: const TextStyle(color: Ui.muted, fontSize: 13)),
                  Text('${(progress * 100).toInt()}%',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Ui.line,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),

        // Question text — scrolls if long, so the scale below never shifts
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${_currentIndex + 1} of $total',
                  style: const TextStyle(color: Ui.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Answer scale — fixed position, independent of question length
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Ui.line, width: 0.5)),
          ),
          child: _buildLikertOptions(id, options),
        ),
      ],
    );
  }

  Widget _buildSummaryPage() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _questions.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Almost there!',
                    style: TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  '$_answeredCount of ${_questions.length} questions answered.',
                  style: const TextStyle(color: Ui.muted, fontSize: 14),
                ),
                if (_answeredCount < _questions.length)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Unanswered questions are highlighted.',
                        style: TextStyle(color: Ui.bad, fontSize: 13)),
                  ),
              ],
            ),
          );
        }
        final q = _questions[index - 1];
        final id = q['id'] as int;
        final text = q['text'] as String;
        final options = (q['options'] as List<dynamic>).cast<Map<String, dynamic>>();
        final selectedId = _selectedOptions[id];
        final selectedOption = selectedId != null
            ? options.firstWhere((o) => o['id'] == selectedId, orElse: () => {})
            : null;
        final selectedValue = selectedOption?['value'] as int?;
        final unanswered = selectedId == null;

        return GestureDetector(
          onTap: () => _goTo(index - 1),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: unanswered ? Ui.badSoft : Ui.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppTheme.cardShadow,
              border: unanswered ? Border.all(color: Ui.badSoft) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$index.',
                    style: const TextStyle(color: Ui.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13, height: 1.4)),
                ),
                const SizedBox(width: 10),
                unanswered
                    ? const Text('—', style: TextStyle(color: Ui.bad, fontWeight: FontWeight.w600))
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text('$selectedValue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final isFirst = _currentIndex == 0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.primary, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errorMessage != null && _onSummary) ...[
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Ui.bad, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          if (_onSummary) ...[
            if (_answeredCount < _questions.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_questions.length - _answeredCount} question(s) still unanswered. Tap any highlighted row to answer it.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Ui.bad, fontSize: 13),
                ),
              ),
            Container(
              alignment: Alignment.centerRight,
              height: 44,
              child: ElevatedButton(
                onPressed: (_submitting || _answeredCount < _questions.length) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  disabledBackgroundColor: Ui.surface3,
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Submit Assessment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]
          else
            Row(
              children: [
                // Back
                SizedBox(
                  width: 50,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: isFirst ? null : () => _goTo(_currentIndex - 1),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: isFirst ? Ui.line : AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),

                // Jump counter
                Expanded(
                  child: GestureDetector(
                    onTap: _showJumpSheet,
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Ui.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Q${_currentIndex + 1} of ${_questions.length}',
                        style: const TextStyle(
                          color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Next / Review
                SizedBox(
                  width: _currentIndex == _questions.length - 1 ? 110 : 50,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _goTo(_currentIndex + 1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      elevation: 0, padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _currentIndex == _questions.length - 1
                        ? const Text('Review', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                        : const Icon(Icons.arrow_forward, size: 20),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLikertOptions(int questionId, List<Map<String, dynamic>> options) {
    final sorted = List<Map<String, dynamic>>.from(options)
      ..sort((a, b) => ((a['value'] as int?) ?? 0).compareTo((b['value'] as int?) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: sorted.map((opt) {
            final optId = opt['id'] as int;
            final optValue = opt['value'] as int? ?? 0;
            final isSelected = _selectedOptions[questionId] == optId;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedOptions[questionId] = optId),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Ui.line,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$optValue',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Ui.muted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(sorted.isNotEmpty ? (sorted.first['text'] as String? ?? '') : '',
                style: const TextStyle(color: Ui.muted, fontSize: 11)),
            Text(sorted.isNotEmpty ? (sorted.last['text'] as String? ?? '') : '',
                style: const TextStyle(color: Ui.muted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
