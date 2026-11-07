import 'package:flutter/material.dart';
import 'package:aidvise_platform/shared/utils/app_theme.dart';

/// Job listing card shared by the matched-jobs and browse screens.
///
/// Applying is one flow: [onApply] runs the tailored-resume generation for
/// this job, and the application is submitted automatically with the
/// generated resume once it's ready.
class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onApply;

  /// Opens the job details sheet; the whole card is tappable.
  final VoidCallback? onTap;

  const JobCard({super.key, required this.job, required this.onApply, this.onTap});

  @override
  Widget build(BuildContext context) {
    final applied = job['applied'] == true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job['title'] as String? ?? '',
              style: const TextStyle(color: AppTheme.primary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(job['company'] as String? ?? '',
              style: const TextStyle(color: Color(0xFF444444), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF888888)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(job['location'] as String? ?? '',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 14, color: Color(0xFF888888)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(job['salary'] as String? ?? '',
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(job['description'] as String? ?? '',
              style: const TextStyle(color: Color(0xFF555555), fontSize: 13, height: 1.45)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: Text(job['type'] as String? ?? '',
                    style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
              ),
              if (job['source'] == 'sample') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Sample',
                      style: TextStyle(color: Color(0xFF999999), fontSize: 11)),
                ),
              ],
              const Spacer(),
              Text(job['posted'] as String? ?? '',
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: applied ? null : onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, foregroundColor: Colors.white, elevation: 0,
                disabledBackgroundColor: const Color(0xFFE0E0E0),
                disabledForegroundColor: const Color(0xFF888888),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(applied ? 'Applied' : 'Apply with Tailored Resume',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ));
  }
}
